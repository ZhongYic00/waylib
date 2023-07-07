// Copyright (C) 2023 JiDe Zhang <zhangjide@deepin.org>.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

#include "woutputrenderwindow.h"
#include "woutput.h"
#ifndef WAYLIB_DISABLE_OUTPUT_DAMAGE
#include "woutputdamage.h"
#endif
#include "woutputhelper.h"
#include "wserver.h"
#include "wbackend.h"
#include "woutputlayout.h"
#include "woutputviewport.h"
#include "wquickbackend_p.h"
#include "wquickoutputlayout.h"
#include "wwaylandcompositor_p.h"

#include "platformplugin/qwlrootsintegration.h"
#include "platformplugin/qwlrootscreen.h"
#include "platformplugin/types.h"

#include <qwoutput.h>
#include <qwoutputlayout.h>
#include <qwrenderer.h>
#include <qwbackend.h>
#include <qwallocator.h>
#include <qwcompositor.h>

#include <QOffscreenSurface>
#include <QQuickRenderControl>

#include <private/qquickwindow_p.h>
#include <private/qquickrendercontrol_p.h>
#include <private/qquickwindow_p.h>
#include <private/qrhi_p.h>
#include <private/qsgrhisupport_p.h>
#include <private/qquicktranslate_p.h>
#include <private/qquickitemchangelistener_p.h>
#include <private/qquickitem_p.h>
#include <private/qquickanimatorcontroller_p.h>
#include <private/qsgabstractrenderer_p.h>
#include <private/qsgrenderer_p.h>

extern "C" {
#define static
#include <wlr/render/wlr_renderer.h>
#include <wlr/render/gles2.h>
#undef static
#ifndef WAYLIB_DISABLE_OUTPUT_DAMAGE
#include <wlr/types/wlr_output_damage.h>
#endif
#include <wlr/render/pixman.h>
#include <wlr/render/egl.h>
#include <wlr/render/pixman.h>
#ifdef ENABLE_VULKAN_RENDER
#include <wlr/render/vulkan.h>
#endif
#include <wlr/util/region.h>
#include <wlr/types/wlr_output.h>
}

WAYLIB_SERVER_BEGIN_NAMESPACE

struct Q_DECL_HIDDEN QScopedPointerPixmanRegion32Deleter {
    static inline void cleanup(pixman_region32_t *pointer) {
        if (pointer)
            pixman_region32_fini(pointer);
        delete pointer;
    }
};

typedef QScopedPointer<pixman_region32_t, QScopedPointerPixmanRegion32Deleter> pixman_region32_scoped_pointer;

class OutputHelper : public WOutputHelper, public QQuickItemChangeListener
{
public:
    OutputHelper(WOutputViewport *output, WOutputRenderWindow *parent)
        : WOutputHelper(output->output(), parent)
        , m_output(output)
    {
        QQuickItemPrivate::get(output)->addItemChangeListener(this, QQuickItemPrivate::Geometry);
        connect(this, &OutputHelper::requestRender, parent, &WOutputRenderWindow::render);
    }
    ~OutputHelper()
    {
        if (m_output)
            QQuickItemPrivate::get(m_output)->removeItemChangeListener(this, QQuickItemPrivate::Geometry);
    }

    inline QWOutput *qwoutput() const {
        return output()->output()->nativeInterface<QWOutput>();
    }

    inline WOutputRenderWindow *renderWindow() const {
        return static_cast<WOutputRenderWindow*>(parent());
    }

    WOutputViewport *output() const {
        return m_output.get();
    }

    void itemGeometryChanged(QQuickItem *, QQuickGeometryChange, const QRectF & /* oldGeometry */) override;

private:
    QPointer<WOutputViewport> m_output;
};

class RenderControl : public QQuickRenderControl
{
public:
    RenderControl() = default;

    QWindow *renderWindow(QPoint *) override {
        return m_renderWindow;
    }

    QWindow *m_renderWindow = nullptr;
};

class WOutputRenderWindowPrivate : public QQuickWindowPrivate
{
public:
    WOutputRenderWindowPrivate(WOutputRenderWindow *)
        : QQuickWindowPrivate() {

    }

    static inline WOutputRenderWindowPrivate *get(WOutputRenderWindow *qq) {
        return qq->d_func();
    }

    void setVisible(bool) override {
        qFatal("Don't visible the window");
    }

    inline RenderControl *rc() const {
        return static_cast<RenderControl*>(q_func()->renderControl());
    }

    void init();
    void init(OutputHelper *helper);
    bool initRCWithRhi();
    void updateWindowSize();

    void doRender();

    inline void render() {
        if (!contentTranslate)
            return; // Not initialized

        for (auto output : outputs)
            output->update();
        doRender();
    }

    void insertOutputToOrderList(WOutputViewport *output);

    Q_DECLARE_PUBLIC(WOutputRenderWindow)

    WWaylandCompositor *compositor = nullptr;

    WQuickOutputLayout *layout = nullptr;
    QList<OutputHelper*> outputs;
    QList<WOutputViewport*> xOrderOutputs;
    QList<WOutputViewport*> yOrderOutputs;

    QQuickTranslate *contentTranslate = nullptr;
    QQuickScale *contentScale = nullptr;

    QOpenGLContext *glContext = nullptr;
#ifdef ENABLE_VULKAN_RENDER
    QScopedPointer<QVulkanInstance> vkInstance;
#endif
};

void OutputHelper::itemGeometryChanged(QQuickItem *, QQuickGeometryChange, const QRectF &)
{
    auto rwd = WOutputRenderWindowPrivate::get(renderWindow());
    rwd->insertOutputToOrderList(m_output);
    rwd->updateWindowSize();

    QMetaObject::invokeMethod(renderWindow(), &WOutputRenderWindow::outputLayoutChanged, Qt::QueuedConnection);
}

void WOutputRenderWindowPrivate::init()
{
    Q_ASSERT(compositor);
    Q_Q(WOutputRenderWindow);

    Q_ASSERT(!contentTranslate);
    contentTranslate = new QQuickTranslate(contentItem);
    contentTranslate->appendToItem(contentItem);
    contentScale = new QQuickScale(contentItem);
    contentScale->appendToItem(contentItem);

    initRCWithRhi();

    for (auto output : outputs)
        init(output);
    Q_ASSERT(xOrderOutputs.count() == outputs.count());
    Q_ASSERT(yOrderOutputs.count() == outputs.count());

    /* Ensure call the "requestRender" on later via Qt::QueuedConnection, if not will crash
    at "Q_ASSERT(prevDirtyItem)" in the QQuickItem, because the QQuickRenderControl::render
    will trigger the QQuickWindow::sceneChanged signal that trigger the
    QQuickRenderControl::sceneChanged, this is a endless loop calls.

    Functions call list:
    0. WOutput::requestRender
    1. QQuickRenderControl::render
    2. QQuickWindowPrivate::renderSceneGraph
    3. QQuickItemPrivate::addToDirtyList
    4. QQuickWindowPrivate::dirtyItem
    5. QQuickWindow::maybeUpdate
    6. QQuickRenderControlPrivate::maybeUpdate
    7. QQuickRenderControl::sceneChanged
    */
    // TODO: Get damage regions from the Qt, and use WOutputDamage::add instead of WOutput::requestRender.
    QObject::connect(rc(), &QQuickRenderControl::renderRequested,
                     q, &WOutputRenderWindow::render, Qt::QueuedConnection);
    QObject::connect(rc(), &QQuickRenderControl::sceneChanged,
                     q, &WOutputRenderWindow::render, Qt::QueuedConnection);

    Q_EMIT q->outputLayoutChanged();
}

void WOutputRenderWindowPrivate::init(OutputHelper *helper)
{
    auto qwoutput = helper->qwoutput();
    qwoutput->initRender(compositor->allocator(), compositor->renderer());
    insertOutputToOrderList(helper->output());
    if (layout)
        layout->add(helper->output());

    QMetaObject::invokeMethod(q_func(), &WOutputRenderWindow::render, Qt::QueuedConnection);
}

inline static QByteArrayList fromCStyleList(size_t count, const char **list) {
    QByteArrayList al;
    al.reserve(count);
    for (size_t i = 0; i < count; ++i) {
        al.append(list[i]);
    }
    return al;
}

bool WOutputRenderWindowPrivate::initRCWithRhi()
{
    W_Q(WOutputRenderWindow);

    QQuickRenderControlPrivate *rcd = QQuickRenderControlPrivate::get(rc());
    QSGRhiSupport *rhiSupport = QSGRhiSupport::instance();

// sanity check for Vulkan
#ifdef ENABLE_VULKAN_RENDER
    if (rhiSupport->rhiBackend() == QRhi::Vulkan) {
        vkInstance.reset(new QVulkanInstance());

        auto phdev = wlr_vk_renderer_get_physical_device(compositor->renderer()->handle());
        auto dev = wlr_vk_renderer_get_device(compositor->renderer()->handle());
        auto queue_family = wlr_vk_renderer_get_queue_family(compositor->renderer()->handle());

#if QT_VERSION > QT_VERSION_CHECK(6, 6, 0)
        auto instance = wlr_vk_renderer_get_instance(compositor->renderer()->handle());
        vkInstance->setVkInstance(instance);
#endif
        //        vkInstance->setExtensions(fromCStyleList(vkRendererAttribs.extension_count, vkRendererAttribs.extensions));
        //        vkInstance->setLayers(fromCStyleList(vkRendererAttribs.layer_count, vkRendererAttribs.layers));
        vkInstance->setApiVersion({1, 1, 0});
        vkInstance->create();
        q->setVulkanInstance(vkInstance.data());

        auto gd = QQuickGraphicsDevice::fromDeviceObjects(phdev, dev, queue_family);
        q->setGraphicsDevice(gd);
    } else
#endif
    if (rhiSupport->rhiBackend() == QRhi::OpenGLES2) {
        Q_ASSERT(wlr_renderer_is_gles2(compositor->renderer()->handle()));
        auto egl = wlr_gles2_renderer_get_egl(compositor->renderer()->handle());
        auto display = wlr_egl_get_display(egl);
        auto context = wlr_egl_get_context(egl);

        this->glContext = new QW::OpenGLContext(display, context, rc());
        bool ok = this->glContext->create();
        if (!ok)
            return false;

        q->setGraphicsDevice(QQuickGraphicsDevice::fromOpenGLContext(this->glContext));
    } else {
        return false;
    }

    QOffscreenSurface *offscreenSurface = new QW::OffscreenSurface(nullptr, q);
    offscreenSurface->create();

    QSGRhiSupport::RhiCreateResult result = rhiSupport->createRhi(q, offscreenSurface);
    if (!result.rhi) {
        qWarning("WOutput::initRhi: Failed to initialize QRhi");
        return false;
    }

    rcd->rhi = result.rhi;
    // Ensure the QQuickRenderControl don't reinit the RHI
    rcd->ownRhi = true;
    if (!rc()->initialize())
        return false;
    rcd->ownRhi = result.own;
    Q_ASSERT(rcd->rhi == result.rhi);

    return true;
}

void WOutputRenderWindowPrivate::updateWindowSize()
{
    QPointF maxPos;

    for (auto o : outputs) {
        const QRectF og(o->output()->position(), o->output()->size());
        if (og.right() > maxPos.x())
            maxPos.rx() = og.right();
        if (og.bottom() > maxPos.y())
            maxPos.ry() = og.bottom();
    }

    q_func()->resize(qRound(maxPos.x()), qRound(maxPos.y()));
}

void WOutputRenderWindowPrivate::doRender()
{
    bool needPolishItems = true;
    for (OutputHelper *helper : outputs) {
        if (!helper->renderable() || !helper->output()->isVisible())
            continue;

#ifndef WAYLIB_DISABLE_OUTPUT_DAMAGE
        pixman_region32_scoped_pointer damage(new pixman_region32_t);
        pixman_region32_init(damage.data());
        if (!helper->attachRender(damage.data()))
            continue;
#else
        if (!helper->contentIsDirty()) {
            helper->resetState();
            helper->qwoutput()->commit();
            continue;
        }
#endif
        if (needPolishItems)
            rc()->polishItems();

        if (Q_UNLIKELY(!helper->makeCurrent(glContext)))
            continue;

#ifndef WAYLIB_DISABLE_OUTPUT_DAMAGE
        if (pixman_region32_not_empty(damage.data()))
#endif
        {
            // TODO: Don't change render window when rendering
            rc()->m_renderWindow = helper->outputWindow();
            // TODO: cache render target
            q_func()->setRenderTarget(helper->makeRenderTarget());
            contentTranslate->setX(-helper->output()->x());
            contentTranslate->setY(-helper->output()->y());

            // TODO: new render thread
            rc()->beginFrame();
            rc()->sync();

            // TODO: use scissor with the damage regions for render.
            rc()->render();
            rc()->endFrame();
        }

#ifndef WAYLIB_DISABLE_OUTPUT_DAMAGE
        const QSize size = transformedSize();
        enum wl_output_transform transform =
            wlr_output_transform_invert(qwoutput()->handle()->transform);

        pixman_region32_scoped_pointer frame_damage(new pixman_region32_t);
        pixman_region32_init(frame_damage.data());
        wlr_region_transform(frame_damage.data(), &this->damage->nativeInterface<wlr_output_damage>()->current,
                             transform, size.width(), size.height());
        qwoutput()->setDamage(frame_damage.data());
        pixman_region32_fini(frame_damage.data());
#endif

        //    auto dirtyFlags = qwoutput()->handle()->pending.committed;
        helper->resetState();
        helper->qwoutput()->commit();
        helper->doneCurrent(glContext);
    }
}

void WOutputRenderWindowPrivate::insertOutputToOrderList(WOutputViewport *output)
{
    bool xFinished = false;
    bool yFinished = false;

    for (int i = 0, j = 0; i < xOrderOutputs.count() || j < yOrderOutputs.count(); ++i, ++j) {
        if (i < xOrderOutputs.count()) {
            auto o = xOrderOutputs.at(i);
            if (o == output) {
                xOrderOutputs.removeAt(i);
                --i;
            } else if (output->x() < o->x()) {
                xOrderOutputs.insert(i, output);
                ++i;
                xFinished = true;
            }
        }

        if (j < yOrderOutputs.count()) {
            auto o = yOrderOutputs.at(j);
            if (o == output) {
                yOrderOutputs.removeAt(j);
                --j;
            } else if (output->y() < o->y()) {
                xOrderOutputs.insert(j, output);
                ++j;
                yFinished = true;
            }
        }
    }

    if (!xFinished)
        xOrderOutputs.append(output);

    if (!yFinished)
        yOrderOutputs.append(output);
}

// TODO: Support QWindow::setCursor
WOutputRenderWindow::WOutputRenderWindow(QObject *parent)
    : QQuickWindow(*new WOutputRenderWindowPrivate(this), new RenderControl())
{
    if (parent)
        QObject::setParent(parent);
}

WOutputRenderWindow::~WOutputRenderWindow()
{
    delete renderControl();
}

QQuickRenderControl *WOutputRenderWindow::renderControl() const
{
    auto wd = QQuickWindowPrivate::get(this);
    return wd->renderControl;
}

void WOutputRenderWindow::attachOutput(WOutputViewport *output)
{
    Q_D(WOutputRenderWindow);

    Q_ASSERT(std::find_if(d->outputs.cbegin(), d->outputs.cend(), [output] (OutputHelper *h) {
                 return h->output() == output;
    }) == d->outputs.cend());

    Q_ASSERT(output->output());

    d->outputs << new OutputHelper(output, this);
    d->updateWindowSize();

    if (!d->renderer)
        return;

    d->init(d->outputs.last());
    Q_ASSERT(d->xOrderOutputs.count() == d->outputs.count());
    Q_ASSERT(d->yOrderOutputs.count() == d->outputs.count());
    d->doRender();

    Q_EMIT outputLayoutChanged();
}

void WOutputRenderWindow::detachOutput(WOutputViewport *output)
{
    Q_D(WOutputRenderWindow);

    OutputHelper *helper = nullptr;
    for (int i = 0; i < d->outputs.size(); ++i) {
        if (d->outputs.at(i)->output() == output) {
            helper = d->outputs.at(i);
            d->outputs.removeAt(i);
            break;
        }
    }
    Q_ASSERT(helper);
    helper->deleteLater();

    d->xOrderOutputs.removeOne(output);
    d->yOrderOutputs.removeOne(output);
    Q_ASSERT(d->xOrderOutputs.size() == d->outputs.size());
    Q_ASSERT(d->yOrderOutputs.size() == d->outputs.size());

    d->updateWindowSize();

    if (d->layout) {
        d->layout->remove(output);
        Q_EMIT outputLayoutChanged();
    }
}

QList<WOutputViewport*> WOutputRenderWindow::getIntersectedOutputs(const QRectF &geometry) const
{
    Q_D(const WOutputRenderWindow);

    QList<WOutputViewport*> outputs;

    for (auto helper : d->outputs) {
        auto o = helper->output();
        const QRectF og(o->position(), o->size());
        if (og.intersects(geometry))
            outputs << o;
    }

    return outputs;
}

QPointF WOutputRenderWindow::mapToNonScaleGlobal(const QPointF &pos) const
{
    Q_D(const WOutputRenderWindow);

    Q_ASSERT(d->outputs.size() == d->xOrderOutputs.size() && d->outputs.size() == d->yOrderOutputs.size());
    // ###: ensure the window position is global
    const QPointF windowPos = position();

    if (pos.isNull())
        return windowPos;

    QPointF globalPos;
    QPointF tmp;

    for (int i = 0; i < d->outputs.size(); ++i) {
        if (tmp.x() < pos.x()) {
            auto o = d->xOrderOutputs.at(i);

            if (tmp.x() < o->x()) {
                globalPos.rx() += (o->x() - tmp.x());
                tmp.rx() = o->x();
            } else if (tmp.x() < o->x() + o->width()) {
                const qreal increment = qMin(pos.x(), o->x() + o->width()) - tmp.x();
                Q_ASSERT(increment > 0);
                globalPos.rx() += increment * o->scale();
                tmp.rx() = o->x() + o->width();
            }
        }


        if (tmp.y() < pos.y()) {
            auto o = d->yOrderOutputs.at(i);

            if (tmp.y() < o->y()) {
                globalPos.ry() += (o->y() - tmp.y());
                tmp.ry() = o->y();
            } else if (tmp.y() < o->y() + o->height()) {
                const qreal increment = qMin(pos.y(), o->y() + o->height()) - tmp.y();
                Q_ASSERT(increment > 0);
                globalPos.ry() += increment * o->scale();
                tmp.ry() = o->y() + o->height();
            }
        }
    }

    return globalPos + windowPos;
}

WWaylandCompositor *WOutputRenderWindow::compositor() const
{
    Q_D(const WOutputRenderWindow);
    return d->compositor;
}

void WOutputRenderWindow::setCompositor(WWaylandCompositor *newCompositor)
{
    Q_D(WOutputRenderWindow);
    Q_ASSERT(!d->compositor);
    d->compositor = newCompositor;

    if (d->componentCompleted && d->compositor->isPolished()) {
        d->init();
    } else {
        connect(newCompositor, &WWaylandCompositor::afterPolish, this, [d] {
            if (d->componentCompleted)
                d->init();
        });
    }
}

WQuickOutputLayout *WOutputRenderWindow::layout() const
{
    Q_D(const WOutputRenderWindow);
    return d->layout;
}

void WOutputRenderWindow::setLayout(WQuickOutputLayout *layout)
{
    Q_D(WOutputRenderWindow);
    Q_ASSERT(!d->layout);

//    if (d->layout) {
//        for (auto o : d->outputs)
//            d->layout->remove(o->output());
//    }

    d->layout = layout;
//    Q_EMIT layoutChanged();

    for (auto o : d->outputs)
        d->layout->add(o->output());
}

void WOutputRenderWindow::render()
{
    Q_D(WOutputRenderWindow);
    d->render();
}

void WOutputRenderWindow::classBegin()
{
    Q_D(WOutputRenderWindow);
    d->componentCompleted = false;
}

void WOutputRenderWindow::componentComplete()
{
    Q_D(WOutputRenderWindow);
    d->componentCompleted = true;

    if (d->compositor && d->compositor->isPolished())
        d->init();
}

WAYLIB_SERVER_END_NAMESPACE