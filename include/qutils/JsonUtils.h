#pragma once
// Qt
#include <QVariantMap>

namespace zmc
{

class JsonUtils
{
public:
    JsonUtils();

    static QString toJsonString(const QVariantMap &data);
    static QString toJsonString(const QVariant &data);
    static QString toJsonString(const QList<QVariant> &data);

    static QVariantMap toVariantMap(const QString &data);
    static QList<QVariant> toVariantList(const QString &data);
};

}
