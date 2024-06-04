// Copyright (C) 2023 JiDe Zhang <zhangjide@deepin.org>.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

#include "wglobal.h"

#include <private/qobject_p_p.h>

WAYLIB_SERVER_BEGIN_NAMESPACE

wl_client *WObject::waylandClient() const
{
    return w_d_ptr->waylandClient();
}

WObject::WObject(WObjectPrivate &dd, WObject *)
    : w_d_ptr(&dd)
{

}

WObject::~WObject()
{

}

WObjectPrivate *WObjectPrivate::get(WObject *qq)
{
    return qq->d_func();
}

WObjectPrivate::WObjectPrivate(WObject *qq)
    : q_ptr(qq)
{

}
WObjectPrivate::~WObjectPrivate()
{

}

WWrapObject::WWrapObject(WWrapObjectPrivate &d, QObject *parent)
    : WObject(d, nullptr)
    , QObject(parent)
{

}

WWrapObject::~WWrapObject()
{
    W_D(WWrapObject);
    d->invalidate();
}

WWrapObjectPrivate::WWrapObjectPrivate(WWrapObject *q)
    : WObjectPrivate(q)
{

}

WWrapObjectPrivate::~WWrapObjectPrivate()
{
    // WWrapObject must destroy by safeDelete or safeDeleteLater
    Q_ASSERT(invalidated);
}

void WWrapObjectPrivate::invalidate()
{
    invalidated = true;
    instantRelease();
    for (const auto &connection : std::as_const(connections))
        QObject::disconnect(connection);
    connections.clear();
}

bool WWrapObject::safeDisconnect(const QObject *receiver)
{
    W_D(WWrapObject);
    bool ok = false;
    for (int i = 0; i < d->connections.size(); ++i) {
        const QMetaObject::Connection &connection = d->connections.at(i);

        static_assert(sizeof(connection) == sizeof(void*),
                      "Please check how to use QMetaObject::Connection::d_ptr");
        auto c_d = *reinterpret_cast<QObjectPrivate::Connection**>(const_cast<QMetaObject::Connection*>(&connection));
        if (c_d->receiver == receiver) {
            if (QObject::disconnect(connection))
                ok = true;
            d->connections.removeAt(i);
            // reset index
            --i;
        }
    }

    return ok;
}

bool WWrapObject::safeDisconnect(const QMetaObject::Connection &connection)
{
    W_D(WWrapObject);
    int index = d->connections.indexOf(connection);
    if (index < 0)
        return false;
    d->connections.removeAt(index);
    return QObject::disconnect(connection);
}

void WWrapObject::safeDeleteLater()
{
    W_D(WWrapObject);
    d->invalidate();

    auto object = dynamic_cast<QObject*>(this);
    Q_ASSERT(object);
    object->deleteLater();
}

WAYLIB_SERVER_END_NAMESPACE
