// Copyright (C) 2023 JiDe Zhang <zhangjide@deepin.org>.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

#pragma once

#include <qwconfig.h>
#include <qtguiglobal.h>

#define SERVER_NAMESPACE Server
#define WAYLIB_SERVER_NAMESPACE Waylib::SERVER_NAMESPACE

#ifndef SERVER_NAMESPACE
#   define WAYLIB_SERVER_BEGIN_NAMESPACE
#   define WAYLIB_SERVER_END_NAMESPACE
#   define WAYLIB_SERVER_USE_NAMESPACE
#else
#   define WAYLIB_SERVER_BEGIN_NAMESPACE namespace Waylib { namespace SERVER_NAMESPACE {
#   define WAYLIB_SERVER_END_NAMESPACE }}
#   define WAYLIB_SERVER_USE_NAMESPACE using namespace WAYLIB_SERVER_NAMESPACE;
#endif

#if defined(WAYLIB_STATIC_LIB)
#  define WAYLIB_SERVER_EXPORT
#else
#if defined(LIBWAYLIB_SERVER_LIBRARY)
#  define WAYLIB_SERVER_EXPORT Q_DECL_EXPORT
#else
#  define WAYLIB_SERVER_EXPORT Q_DECL_IMPORT
#endif
#endif

#define W_DECLARE_PRIVATE(Class) Q_DECLARE_PRIVATE_D(qGetPtrHelper(w_d_ptr),Class)
#define W_DECLARE_PUBLIC(Class) Q_DECLARE_PUBLIC(Class)
#define W_D(Class) Q_D(Class)
#define W_Q(Class) Q_Q(Class)
#define W_DC(Class) Q_D(const Class)
#define W_QC(Class) Q_Q(const Class)
#define W_PRIVATE_SLOT(Func) Q_PRIVATE_SLOT(d_func(), Func)

#if defined(WLR_HAVE_VULKAN_RENDERER) && QT_CONFIG(vulkan) && WLR_VERSION_MINOR > 16
#define ENABLE_VULKAN_RENDER
#endif

#ifndef WLR_HAVE_XWAYLAND
#ifndef DISABLE_XWAYLAND
#define DISABLE_XWAYLAND
#endif
#endif

#include <QScopedPointer>
#include <QList>
#include <QObject>
#include <QThread>

#include <type_traits>

struct wl_client;
WAYLIB_SERVER_BEGIN_NAMESPACE

class WObject;
class WObjectPrivate
{
public:
    static WObjectPrivate *get(WObject *qq);

    virtual ~WObjectPrivate();
    virtual wl_client *waylandClient() const {
        return nullptr;
    }

protected:
    WObjectPrivate(WObject *qq);

    inline int indexOfAttachedData(const void *owner) const {
        for (int i = 0; i < attachedDatas.count(); ++i)
            if (attachedDatas.at(i).first == owner)
                return i;
        return -1;
    }

    void invalidate();
    virtual void instantRelease() {}

    WObject *q_ptr;
    QList<std::pair<const void*, void*>> attachedDatas;
    QList<QMetaObject::Connection> connections;
    bool invalidated = false;

    Q_DECLARE_PUBLIC(WObject)
};
template<typename T>
concept IsPublicDestructible = requires(T *t){
    delete t;
};
class WAYLIB_SERVER_EXPORT WObject
{
public:
    template<typename T>
    T *getAttachedData(const void *owner) const {
        void *data = w_d_ptr->attachedDatas.value(w_d_ptr->indexOfAttachedData(owner)).second;
        return reinterpret_cast<T*>(data);
    }
    template<typename T>
    T *getAttachedData() const {
        const void *owner = typeid(T).name();
        return getAttachedData<T>(owner);
    }

    template<typename T>
    void setAttachedData(const void *owner, void *data) {
        Q_ASSERT(w_d_ptr->indexOfAttachedData(owner) < 0);
        w_d_ptr->attachedDatas.append({owner, data});
    }
    template<typename T>
    void setAttachedData(void *data) {
        const void *owner = typeid(T).name();
        setAttachedData<T>(owner, data);
    }

    template<typename T>
    void removeAttachedData(const void *owner) {
        int index = w_d_ptr->indexOfAttachedData(owner);
        Q_ASSERT(index >= 0);
        w_d_ptr->attachedDatas.removeAt(index);
    }
    template<typename T>
    void removeAttachedData() {
        const void *owner = typeid(T).name();
        removeAttachedData<T>(owner);
    }

    wl_client *waylandClient() const;

    template<typename Func1, typename Func2>
    static typename std::enable_if<std::is_base_of<WObject, typename QtPrivate::FunctionPointer<Func1>::Object>::value, QMetaObject::Connection>::type
    safeConnect(const typename QtPrivate::FunctionPointer<Func1>::Object *sender,
                Func1 signal, const QObject *receiver, Func2 slot,
                Qt::ConnectionType type = Qt::AutoConnection) {
        auto connection = QObject::connect(sender, signal, receiver, slot, type);
        if (!connection)
            return connection;

        // Isn't thread safety
        Q_ASSERT(QThread::currentThread() == sender->thread());
        auto d = static_cast<WWrapObjectPrivate*>(static_cast<const WWrapObject*>(sender)->w_d_ptr.get());
        Q_ASSERT(!d->invalidated);
        d->connections.append(connection);
        return connection;
    }

    template<typename T, typename Func1, typename Func2>
    static QMetaObject::Connection
    safeConnect(const T *sender, Func1 signal, const QObject *receiver, Func2 slot, Qt::ConnectionType type = Qt::AutoConnection)
                requires std::is_base_of_v<WObject, T>
                && (!std::is_base_of_v<WObject, typename QtPrivate::FunctionPointer<Func1>::Object>)
                && requires(T t) { std::is_base_of_v<typename QtPrivate::FunctionPointer<Func1>::Object,decltype(*t.handle())>; }
                {
        auto connection = QObject::connect(sender->handle(), signal, receiver, slot, type);
        if (!connection)
            return connection;

        // Isn't thread safety
        Q_ASSERT(QThread::currentThread() == sender->thread());
        auto d = static_cast<WWrapObjectPrivate*>(static_cast<const WWrapObject*>(sender)->w_d_ptr.get());
        Q_ASSERT(!d->invalidated);
        d->connections.append(connection);
        return connection;
    }

    bool safeDisconnect(const QObject *receiver);
    bool safeDisconnect(const QMetaObject::Connection &connection);

    // release resources requiring instant release, then QObject::deleteLater
    void safeDeleteLater();

protected:
    WObject(WObjectPrivate &dd, WObject *parent = nullptr);

    virtual ~WObject();
    QScopedPointer<WObjectPrivate> w_d_ptr;

    Q_DISABLE_COPY(WObject)
    W_DECLARE_PRIVATE(WObject)
};

WAYLIB_SERVER_END_NAMESPACE
