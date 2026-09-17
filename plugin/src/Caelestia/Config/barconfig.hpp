#pragma once

#include <qstring.h>
#include <qstringlist.h>
#include <qvariantlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;
using settings::vmap;

class BarScrollActions : public settings::ObjectNode {
    CONFIG_NODE(BarScrollActions, settings::ObjectNode)

    CONFIG_PROPERTY(bool, workspaces, true)
    CONFIG_PROPERTY(bool, volume, true)
    CONFIG_PROPERTY(bool, brightness, true)
};

class BarPopouts : public settings::ObjectNode {
    CONFIG_NODE(BarPopouts, settings::ObjectNode)

    CONFIG_PROPERTY(bool, activeWindow, true)
    CONFIG_PROPERTY(bool, tray, true)
    CONFIG_PROPERTY(bool, statusIcons, true)
};

class BarWorkspaces : public settings::ObjectNode {
    CONFIG_NODE(BarWorkspaces, settings::ObjectNode)

    CONFIG_PROPERTY(int, shown, 5)
    CONFIG_PROPERTY(bool, activeIndicator, true)
    CONFIG_PROPERTY(bool, useIcon, true)
    CONFIG_PROPERTY(bool, occupiedBg, false)
    CONFIG_PROPERTY(bool, showUnoccupied, true)
    CONFIG_PROPERTY(bool, showWindows, true)
    CONFIG_PROPERTY(bool, showWindowsOnSpecialWorkspaces, true)
    CONFIG_PROPERTY(int, maxWindowIcons, 5)
    CONFIG_PROPERTY(bool, activeTrail, false)
    CONFIG_ENUM_PROPERTY(BarWorkspaceDisplay, displayType, BarWorkspaceDisplay::Shapes)
    CONFIG_PROPERTY(QString, label, u"  "_s)
    CONFIG_PROPERTY(QString, occupiedLabel, u"󰮯"_s)
    CONFIG_PROPERTY(QString, activeLabel, u"󰮯"_s)
    CONFIG_ENUM_PROPERTY(BarWorkspaceCapitalisation, capitalisation, BarWorkspaceCapitalisation::Preserve)
    CONFIG_GLOBAL_PROPERTY(QVariantList, specialWorkspaceIcons, {})
    CONFIG_GLOBAL_PROPERTY(QStringList, ignoredTags,
        DEFAULT_ARG({
            u"hide_in_bar"_s,
            u"xwl_popup"_s,
        }))
    CONFIG_GLOBAL_PROPERTY(QVariantList, windowIcons,
        DEFAULT_ARG({
            vmap({
                { u"regex"_s, u"steam(_app_(default|[0-9]+))?"_s },
                { u"icon"_s, u"sports_esports"_s },
            }),
        }))
    CONFIG_GLOBAL_PROPERTY(QVariantList, wsIcons, {})
};

class BarActiveWindow : public settings::ObjectNode {
    CONFIG_NODE(BarActiveWindow, settings::ObjectNode)

    CONFIG_PROPERTY(bool, compact, false)
    CONFIG_PROPERTY(bool, inverted, false)
    CONFIG_PROPERTY(bool, showOnHover, true)
};

class BarTray : public settings::ObjectNode {
    CONFIG_NODE(BarTray, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, recolour, false)
    CONFIG_PROPERTY(bool, compact, false)
    CONFIG_GLOBAL_PROPERTY(QVariantList, iconSubs, {})
    CONFIG_GLOBAL_PROPERTY(QStringList, hiddenIcons, {})
};

class BarClock : public settings::ObjectNode {
    CONFIG_NODE(BarClock, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, showDate, false)
    CONFIG_PROPERTY(bool, showIcon, true)
    CONFIG_PROPERTY(bool, showSeconds, false)
};

class BarDock : public settings::ObjectNode {
    CONFIG_NODE(BarDock, settings::ObjectNode)

    CONFIG_PROPERTY(bool, monitorCenter, true)
    CONFIG_PROPERTY(bool, recolourIcons, false)
};

class BarGithub : public settings::ObjectNode {
    CONFIG_NODE(BarGithub, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, recolourIcons, false)
};

class BarSpotify : public settings::ObjectNode {
    CONFIG_NODE(BarSpotify, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, showVisualiser, true)
    CONFIG_PROPERTY(int, maxTitleLength, 25)
    CONFIG_PROPERTY(bool, inverted, false)
    CONFIG_PROPERTY(bool, horizontalVolume, false)
    CONFIG_PROPERTY(bool, autoHide, false)
};

// Bar entries split into three anchored sections. `start` hugs the top/left edge,
// `center` sits at the monitor centre and `end` hugs the bottom/right edge.
// The legacy flat `bar.entries` array is not migrated; it is rejected by the
// schema sync and the defaults are used instead.
class BarSections : public settings::ObjectNode {
    CONFIG_NODE(BarSections, settings::ObjectNode)

    CONFIG_LIST(EntryList, start,
        DEFAULT_ARG({
            LIST_ENTRY(logo, true),
            LIST_ENTRY(workspaces, true),
        }))
    CONFIG_LIST(EntryList, center,
        DEFAULT_ARG({
            LIST_ENTRY(activeWindow, true),
        }))
    CONFIG_LIST(EntryList, end,
        DEFAULT_ARG({
            LIST_ENTRY(tray, true),
            LIST_ENTRY(clock, true),
            LIST_ENTRY(statusIcons, true),
            LIST_ENTRY(power, true),
        }))
};

class BarConfig : public settings::ObjectNode {
    CONFIG_NODE(BarConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, persistent, true)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_PROPERTY(int, dragThreshold, 20)
    CONFIG_PROPERTY(QString, position, u"left"_s)
    CONFIG_SUBOBJECT(BarScrollActions, scrollActions)
    CONFIG_SUBOBJECT(BarPopouts, popouts)
    CONFIG_SUBOBJECT(BarWorkspaces, workspaces)
    CONFIG_SUBOBJECT(BarActiveWindow, activeWindow)
    CONFIG_SUBOBJECT(BarTray, tray)
    CONFIG_SUBOBJECT(BarClock, clock)
    CONFIG_SUBOBJECT(BarDock, dock)
    CONFIG_SUBOBJECT(BarGithub, github)
    CONFIG_SUBOBJECT(BarSpotify, spotify)
    CONFIG_LIST(EntryList, statusIcons,
        DEFAULT_ARG({
            LIST_ENTRY(lockStatus, true),
            LIST_ENTRY(audio, false),
            LIST_ENTRY(microphone, false),
            LIST_ENTRY(kbLayout, false),
            LIST_ENTRY(network, true),
            LIST_ENTRY(bluetooth, true),
            LIST_ENTRY(battery, true),
            LIST_ENTRY(peripheralBattery, false),
            LIST_ENTRY(notifications, true),
        }))
    CONFIG_SUBOBJECT(BarSections, entries)
    CONFIG_PROPERTY(QStringList, excludedScreens, {})
    CONFIG_PROPERTY(QStringList, peripheralBatteryExcluded, {})
};

} // namespace caelestia::config
