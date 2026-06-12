// Plasma summon, regions, monitor moves, and layout cycling for KWin 6.
// The helper service owns TOML parsing and safe app launching; KWin owns windows.

const SUMMON_SERVICE = "io.techdufus.PlasmaSummon";
const SUMMON_PATH = "/io/techdufus/PlasmaSummon";
const SUMMON_INTERFACE = "io.techdufus.PlasmaSummon";

let apps = {
    terminal: {
        key: "t",
        exec: "ghostty",
        match: [
            "class:com.mitchellh.ghostty",
            "class:ghostty",
            "resourceClass:com.mitchellh.ghostty",
            "resourceClass:ghostty",
            "desktopFileName:com.mitchellh.ghostty",
        ],
        workspace: "1",
        monitor: "HDMI-A-1",
        region: "main",
    },
    browser: {
        key: "b",
        exec: "brave",
        match: [
            "class:brave-browser",
            "class:Brave-browser",
            "resourceClass:brave-browser",
            "resourceClass:Brave-browser",
            "desktopFileName:brave-browser",
        ],
        workspace: "2",
        monitor: "HDMI-A-1",
        region: "wide",
    },
    discord: {
        key: "d",
        exec: "discord",
        match: ["class:discord", "resourceClass:discord", "desktopFileName:discord"],
        workspace: "4",
        monitor: "DP-1",
        region: "chat",
    },
    signal: {
        key: "c",
        exec: "signal-desktop",
        match: [
            "class:signal",
            "class:Signal",
            "resourceClass:signal",
            "resourceClass:Signal",
            "desktopFileName:signal-desktop",
        ],
        workspace: "4",
        monitor: "DP-1",
        region: "chat",
    },
    spotify: {
        key: "s",
        exec: "spotify-launcher",
        match: [
            "class:Spotify",
            "class:spotify",
            "resourceClass:Spotify",
            "resourceClass:spotify",
            "desktopFileName:spotify",
        ],
        workspace: "5",
        monitor: "DP-1",
        region: "side",
    },
    obsidian: {
        key: "n",
        exec: "obsidian",
        match: [
            "class:obsidian",
            "class:Obsidian",
            "resourceClass:obsidian",
            "resourceClass:Obsidian",
            "desktopFileName:obsidian",
        ],
        workspace: "3",
        monitor: "HDMI-A-1",
        region: "side",
    },
    onepassword: {
        key: "o",
        exec: "1password",
        match: [
            "class:1Password",
            "class:1password",
            "resourceClass:1Password",
            "resourceClass:1password",
            "desktopFileName:1password",
        ],
        workspace: "1",
        monitor: "HDMI-A-1",
        region: "center",
    },
    files: {
        key: "f",
        exec: "dolphin",
        match: [
            "class:dolphin",
            "class:org.kde.dolphin",
            "resourceClass:dolphin",
            "resourceClass:org.kde.dolphin",
            "desktopFileName:org.kde.dolphin",
        ],
        workspace: "1",
        monitor: "HDMI-A-1",
        region: "center",
    },
    steam: {
        key: "g",
        exec: "steam",
        match: [
            "class:Steam",
            "class:steam",
            "resourceClass:Steam",
            "resourceClass:steam",
            "desktopFileName:steam",
            "title:Steam",
        ],
        workspace: "6",
        monitor: "HDMI-A-1",
    },
};

let regions = {
    full: { x: "2%", y: "4%", w: "96%", h: "92%", float: true },
    main: { x: "2%", y: "4%", w: "60%", h: "92%", float: true },
    wide: { x: "2%", y: "4%", w: "74%", h: "92%", float: true },
    side: { x: "64%", y: "4%", w: "34%", h: "92%", float: true },
    chat: { x: "62%", y: "7%", w: "36%", h: "86%", float: true },
    center_left: { x: "8%", y: "15%", w: "55%", h: "69%", float: true },
    center: { x: "23%", y: "15%", w: "54%", h: "66%", float: true },
    left: { x: "2%", y: "4%", w: "47%", h: "92%", float: true },
    right: { x: "51%", y: "4%", w: "47%", h: "92%", float: true },
    top_right: { x: "51%", y: "4%", w: "47%", h: "44%", float: true },
    right_small: { x: "60%", y: "22%", w: "38%", h: "55%", float: true },
    bottom_right: { x: "51%", y: "52%", w: "47%", h: "44%", float: true },
};

let layouts = {
    fourk: {
        label: "4K Workspace",
        min_width: 2560,
        cells: ["main", "side", "top_right", "center_left", "center", "right_small"],
        apps: {
            terminal: 1,
            browser: 2,
            discord: 3,
            signal: 3,
            spotify: 4,
            onepassword: 4,
            files: 5,
            obsidian: 6,
        },
    },
    hd: {
        label: "HD Workspace",
        min_width: 0,
        max_width: 2559,
        cells: ["main", "side", "center"],
        apps: {
            terminal: 1,
            browser: 2,
            discord: 3,
            signal: 3,
            spotify: 3,
            onepassword: 3,
            files: 3,
            obsidian: 3,
        },
    },
    full: {
        label: "Fullscreen",
        min_width: 0,
        cells: ["full"],
        apps: {
            terminal: 1,
            browser: 1,
            discord: 1,
            signal: 1,
            spotify: 1,
            onepassword: 1,
            files: 1,
            obsidian: 1,
            steam: 1,
        },
    },
};

const state = {
    activeWindow: workspace.activeWindow,
    previousWindow: null,
    lastByApp: {},
    lastRegionByWindow: {},
    lastCellByWindow: {},
    layoutByOutput: {},
    appCellOverrides: {},
    pendingLaunches: {},
};

function log(message) {
    print("plasma-summon: " + message);
}

function loadRemoteConfig() {
    callDBus(SUMMON_SERVICE, SUMMON_PATH, SUMMON_INTERFACE, "ConfigJson", function (payload) {
        try {
            const loaded = JSON.parse(String(payload || "{}"));
            if (loaded.apps) {
                apps = loaded.apps;
            }
            if (loaded.regions) {
                regions = loaded.regions;
            }
            if (loaded.layouts) {
                layouts = loaded.layouts;
            }
            log("loaded config from helper");
        } catch (error) {
            log("kept embedded config after helper config error: " + error);
        }
    });
}

function objectKeys(object) {
    const keys = [];
    for (const key in object) {
        if (Object.prototype.hasOwnProperty.call(object, key)) {
            keys.push(key);
        }
    }
    return keys;
}

function lower(value) {
    return String(value || "").toLowerCase();
}

function windowId(window) {
    return window ? String(window.internalId || window.pid || window.caption || "") : "";
}

function windowValue(window, field) {
    if (!window) {
        return "";
    }
    if (field === "class" || field === "resourceClass") {
        return String(window.resourceClass || "");
    }
    if (field === "name" || field === "resourceName") {
        return String(window.resourceName || "");
    }
    if (field === "desktopFileName" || field === "app_id") {
        return String(window.desktopFileName || window.resourceClass || "");
    }
    if (field === "title" || field === "caption") {
        return String(window.caption || "");
    }
    return String(window[field] || "");
}

function selectorMatches(window, selector) {
    const index = String(selector).indexOf(":");
    if (index < 0) {
        return false;
    }
    const field = selector.slice(0, index);
    const expected = selector.slice(index + 1);
    const actual = windowValue(window, field);
    if (field === "title" || field === "caption") {
        return lower(actual).indexOf(lower(expected)) >= 0;
    }
    return lower(actual) === lower(expected);
}

function appMatches(window, appConfig) {
    const selectors = appConfig.match || [];
    for (let i = 0; i < selectors.length; i += 1) {
        if (selectorMatches(window, selectors[i])) {
            return true;
        }
    }
    return false;
}

function appForWindow(window) {
    const names = objectKeys(apps);
    for (let i = 0; i < names.length; i += 1) {
        const name = names[i];
        if (appMatches(window, apps[name])) {
            return name;
        }
    }
    return null;
}

function normalWindow(window) {
    return Boolean(
        window &&
        window.managed &&
        !window.deleted &&
        window.normalWindow &&
        !window.specialWindow &&
        window.wantsInput
    );
}

function currentDesktopForOutput(output) {
    if (workspace.currentDesktopForScreen && output) {
        return workspace.currentDesktopForScreen(output);
    }
    return workspace.currentDesktop;
}

function windowOnCurrentDesktop(window) {
    if (!window || !window.desktops || window.desktops.length === 0) {
        return true;
    }
    const desktop = currentDesktopForOutput(window.output);
    for (let i = 0; i < window.desktops.length; i += 1) {
        if (window.desktops[i] === desktop) {
            return true;
        }
    }
    return false;
}

function findWindowById(id) {
    if (!id) {
        return null;
    }
    const windows = workspace.stackingOrder || [];
    for (let i = 0; i < windows.length; i += 1) {
        if (windowId(windows[i]) === id) {
            return windows[i];
        }
    }
    return null;
}

function bestWindow(appName) {
    const appConfig = apps[appName];
    if (!appConfig) {
        return null;
    }

    const remembered = findWindowById(state.lastByApp[appName]);
    if (normalWindow(remembered) && appMatches(remembered, appConfig)) {
        return remembered;
    }

    const active = workspace.activeWindow;
    const windows = workspace.stackingOrder || [];
    let best = null;
    let bestScore = -1;
    for (let i = 0; i < windows.length; i += 1) {
        const window = windows[i];
        if (!normalWindow(window) || !appMatches(window, appConfig)) {
            continue;
        }
        let score = i;
        if (active && window.output === active.output) {
            score += 1000;
        }
        if (windowOnCurrentDesktop(window)) {
            score += 100;
        }
        if (!window.minimized) {
            score += 10;
        }
        if (score > bestScore) {
            best = window;
            bestScore = score;
        }
    }
    return best;
}

function activateWindowDesktop(window) {
    if (!window || !window.desktops || window.desktops.length === 0) {
        return;
    }
    const desktop = window.desktops[0];
    if (desktop) {
        workspace.currentDesktop = desktop;
    }
}

function focusWindow(window) {
    if (!window) {
        return;
    }
    if (window.minimized) {
        window.minimized = false;
    }
    activateWindowDesktop(window);
    workspace.activeWindow = window;
    workspace.raiseWindow(window);
}

function activateAppDesktop(appConfig) {
    const raw = parseInt(String(appConfig.workspace || ""), 10);
    if (!raw || raw < 1 || raw > workspace.desktops.length) {
        return null;
    }
    const desktop = workspace.desktops[raw - 1];
    if (desktop) {
        workspace.currentDesktop = desktop;
    }
    return desktop;
}

function moveWindowToAppDesktop(window, appConfig) {
    const raw = parseInt(String(appConfig.workspace || ""), 10);
    if (!raw || raw < 1 || raw > workspace.desktops.length) {
        return;
    }
    const desktop = workspace.desktops[raw - 1];
    if (desktop) {
        window.desktops = [desktop];
    }
}

function outputByName(name) {
    if (!name) {
        return null;
    }
    const wanted = lower(name);
    const screens = workspace.screens || [];
    for (let i = 0; i < screens.length; i += 1) {
        const output = screens[i];
        const values = [
            output.name,
            output.serialNumber,
            output.model,
            outputKey(output),
        ];
        for (let j = 0; j < values.length; j += 1) {
            if (lower(values[j]) === wanted) {
                return output;
            }
        }
    }
    return null;
}

function targetOutputForApp(appConfig, fallback) {
    if (appConfig && appConfig.monitor) {
        const output = outputByName(appConfig.monitor);
        if (output) {
            return output;
        }
        log("unknown app monitor " + appConfig.monitor);
    }
    return fallback || workspace.activeScreen;
}

function moveWindowToOutput(window, output) {
    if (!normalWindow(window) || !output) {
        return false;
    }
    if (window.output !== output) {
        workspace.sendClientToScreen(window, output);
    }
    return true;
}

function prepareWindowForGeometry(window, region) {
    if (region && region.float === false) {
        return;
    }
    if (window.setMaximize) {
        window.setMaximize(false, false);
    }
    if ("maximized" in window) {
        window.maximized = false;
    }
    if ("maximizedHorizontally" in window) {
        window.maximizedHorizontally = false;
    }
    if ("maximizedVertically" in window) {
        window.maximizedVertically = false;
    }
    if ("quickTileMode" in window) {
        window.quickTileMode = 0;
    }
}

function placeAppWindow(appName, window) {
    const appConfig = apps[appName];
    if (!appConfig || !normalWindow(window)) {
        return false;
    }
    if (window.fullScreen) {
        log("refusing to move fullscreen window");
        return false;
    }

    moveWindowToAppDesktop(window, appConfig);
    const targetOutput = targetOutputForApp(appConfig, window.output || workspace.activeScreen);
    moveWindowToOutput(window, targetOutput);
    focusWindow(window);

    const pair = layoutForOutput(targetOutput);
    if (pair && pair[1]) {
        const cell = configuredAppCell(targetOutput, pair[0], pair[1], appName);
        if (cell && placeWindowInLayoutCell(window, cell, targetOutput, false)) {
            return true;
        }
    }

    if (appConfig.region) {
        return placeWindowInRegion(window, appConfig.region, targetOutput);
    }
    return true;
}

function rememberPendingLaunch(appName, place) {
    state.pendingLaunches[appName] = {
        expiresAt: Date.now() + 10000,
        place: place,
    };
}

function launchApp(appName, place) {
    const appConfig = apps[appName];
    if (!appConfig) {
        log("unknown app " + appName);
        return;
    }
    activateAppDesktop(appConfig);
    rememberPendingLaunch(appName, Boolean(place || appConfig.region || appConfig.monitor));
    callDBus(SUMMON_SERVICE, SUMMON_PATH, SUMMON_INTERFACE, "LaunchApp", appName, function (reply) {
        log(String(reply || "launch requested: " + appName));
    });
}

function summonApp(appName, place) {
    const appConfig = apps[appName];
    if (!appConfig) {
        log("unknown app " + appName);
        return;
    }

    const window = bestWindow(appName);
    if (!window) {
        launchApp(appName, true);
        return;
    }

    state.lastByApp[appName] = windowId(window);
    if (place) {
        placeAppWindow(appName, window);
    } else {
        focusWindow(window);
    }
}

function outputKey(output) {
    return String(output ? output.name || output.serialNumber || output.model || "output" : "output");
}

function outputArea(output) {
    if (!output) {
        output = workspace.activeScreen;
    }
    const desktop = currentDesktopForOutput(output);
    return workspace.clientArea(KWin.PlacementArea, output, desktop);
}

function percentOrPixels(value, total) {
    const text = String(value);
    if (text.slice(-1) === "%") {
        return Math.round((parseFloat(text.slice(0, -1)) / 100) * total);
    }
    return Math.round(parseFloat(text));
}

function regionGeometry(region, output) {
    const area = outputArea(output);
    const width = Math.round(area.width);
    const height = Math.round(area.height);
    return {
        x: Math.round(area.x) + percentOrPixels(region.x || 0, width),
        y: Math.round(area.y) + percentOrPixels(region.y || 0, height),
        width: percentOrPixels(region.w || width, width),
        height: percentOrPixels(region.h || height, height),
    };
}

function placeWindowInRegion(window, regionName, output) {
    if (!normalWindow(window)) {
        return false;
    }
    if (window.fullScreen) {
        log("refusing to move fullscreen window");
        return false;
    }
    const region = regions[regionName];
    if (!region) {
        log("unknown region " + regionName);
        return false;
    }
    prepareWindowForGeometry(window, region);
    const target = regionGeometry(region, output || window.output || workspace.activeScreen);
    window.frameGeometry = target;
    state.lastRegionByWindow[windowId(window)] = regionName;
    workspace.raiseWindow(window);
    return true;
}

function moveActiveToRegion(regionName) {
    placeWindowInRegion(workspace.activeWindow, regionName, null);
}

function layoutNames() {
    return objectKeys(layouts);
}

function layoutForOutput(output) {
    const key = outputKey(output);
    const selected = state.layoutByOutput[key];
    if (selected && layouts[selected]) {
        return [selected, layouts[selected]];
    }

    const area = outputArea(output);
    const width = Math.round(area.width);
    const names = layoutNames();
    for (let i = 0; i < names.length; i += 1) {
        const name = names[i];
        const layout = layouts[name];
        const minWidth = Number(layout.min_width || 0);
        const maxWidth = Number(layout.max_width || 999999);
        if (width >= minWidth && width <= maxWidth) {
            return [name, layout];
        }
    }
    return [names[0], layouts[names[0]]];
}

function setLayoutForOutput(output, layoutName) {
    state.layoutByOutput[outputKey(output)] = layoutName;
}

function appCellOverrideKey(output, layoutName, appName) {
    return outputKey(output) + ":" + layoutName + ":" + appName;
}

function configuredAppCell(output, layoutName, layout, appName) {
    if (!appName) {
        return null;
    }
    const override = state.appCellOverrides[appCellOverrideKey(output, layoutName, appName)];
    if (override) {
        return override;
    }
    if (layout.apps && layout.apps[appName]) {
        return Number(layout.apps[appName]);
    }
    return null;
}

function cellRegion(layout, cellIndex) {
    const cells = layout.cells || [];
    const regionName = cells[cellIndex - 1];
    return regionName || null;
}

function placeWindowInLayoutCell(window, cellIndex, output, rememberOverride) {
    if (!normalWindow(window)) {
        return false;
    }
    const targetOutput = output || window.output || workspace.activeScreen;
    const pair = layoutForOutput(targetOutput);
    const layoutName = pair[0];
    const layout = pair[1];
    const regionName = cellRegion(layout, cellIndex);
    if (!regionName) {
        log("layout " + layoutName + " has no cell " + cellIndex);
        return false;
    }
    const ok = placeWindowInRegion(window, regionName, targetOutput);
    if (ok) {
        const appName = appForWindow(window);
        if (rememberOverride && appName) {
            state.appCellOverrides[appCellOverrideKey(targetOutput, layoutName, appName)] = cellIndex;
        }
        state.lastCellByWindow[windowId(window)] = cellIndex;
    }
    return ok;
}

function placeWindowInCell(window, cellIndex, output) {
    return placeWindowInLayoutCell(window, cellIndex, output, true);
}

function moveActiveToCell(cellIndex) {
    placeWindowInCell(workspace.activeWindow, cellIndex, null);
}

function reapplyLayout(output) {
    const pair = layoutForOutput(output);
    const layoutName = pair[0];
    const layout = pair[1];
    const windows = workspace.stackingOrder || [];
    for (let i = 0; i < windows.length; i += 1) {
        const window = windows[i];
        if (!normalWindow(window) || window.output !== output || window.fullScreen) {
            continue;
        }
        const appName = appForWindow(window);
        const cell = configuredAppCell(output, layoutName, layout, appName);
        if (cell) {
            placeWindowInCell(window, cell, output);
        }
    }
}

function activeOutput() {
    const window = workspace.activeWindow;
    if (window && window.output) {
        return window.output;
    }
    return workspace.activeScreen;
}

function cycleLayout() {
    const output = activeOutput();
    const names = layoutNames();
    const current = layoutForOutput(output)[0];
    const index = names.indexOf(current);
    const next = names[(index + 1) % names.length];
    setLayoutForOutput(output, next);
    reapplyLayout(output);
    log("layout " + outputKey(output) + " -> " + next);
}

function resetLayout() {
    const output = activeOutput();
    delete state.layoutByOutput[outputKey(output)];
    reapplyLayout(output);
    log("layout reset for " + outputKey(output));
}

function sortedOutputs() {
    const screens = workspace.screens || [];
    const outputs = [];
    for (let i = 0; i < screens.length; i += 1) {
        outputs.push(screens[i]);
    }
    outputs.sort(function (left, right) {
        const leftGeometry = left.geometry;
        const rightGeometry = right.geometry;
        if (leftGeometry.x !== rightGeometry.x) {
            return leftGeometry.x - rightGeometry.x;
        }
        return leftGeometry.y - rightGeometry.y;
    });
    return outputs;
}

function otherOutput(current, direction) {
    const outputs = sortedOutputs();
    if (outputs.length < 2) {
        return current;
    }
    let index = outputs.indexOf(current);
    if (index < 0) {
        index = 0;
    }
    const delta = direction === "previous" ? -1 : 1;
    return outputs[(index + delta + outputs.length) % outputs.length];
}

function relativeGeometry(window, sourceArea) {
    const geometry = window.frameGeometry;
    return {
        x: (geometry.x - sourceArea.x) / Math.max(1, sourceArea.width),
        y: (geometry.y - sourceArea.y) / Math.max(1, sourceArea.height),
        width: geometry.width / Math.max(1, sourceArea.width),
        height: geometry.height / Math.max(1, sourceArea.height),
    };
}

function applyRelativeGeometry(window, output, relative) {
    const area = outputArea(output);
    prepareWindowForGeometry(window, null);
    window.frameGeometry = {
        x: Math.round(area.x + relative.x * area.width),
        y: Math.round(area.y + relative.y * area.height),
        width: Math.round(relative.width * area.width),
        height: Math.round(relative.height * area.height),
    };
}

function moveActiveToOutput(direction) {
    const window = workspace.activeWindow;
    if (!normalWindow(window)) {
        return;
    }
    if (window.fullScreen) {
        log("refusing to move fullscreen window");
        return;
    }

    const sourceOutput = window.output || workspace.activeScreen;
    const targetOutput = otherOutput(sourceOutput, direction);
    if (!targetOutput || targetOutput === sourceOutput) {
        return;
    }

    const appName = appForWindow(window);
    const sourceArea = outputArea(sourceOutput);
    const relative = relativeGeometry(window, sourceArea);
    workspace.sendClientToScreen(window, targetOutput);
    focusWindow(window);

    const pair = layoutForOutput(targetOutput);
    const layoutName = pair[0];
    const layout = pair[1];
    const cell = configuredAppCell(targetOutput, layoutName, layout, appName);
    if (cell) {
        placeWindowInCell(window, cell, targetOutput);
    } else if (appName && apps[appName] && apps[appName].region) {
        placeWindowInRegion(window, apps[appName].region, targetOutput);
    } else {
        applyRelativeGeometry(window, targetOutput, relative);
    }
}

function registerAppShortcuts() {
    const names = objectKeys(apps);
    const triggerPrefixes = ["F13", "CapsLock", "Tools"];
    for (let i = 0; i < names.length; i += 1) {
        const appName = names[i];
        const app = apps[appName];
        const key = String(app.key || "").toUpperCase();
        if (!key) {
            continue;
        }
        for (let j = 0; j < triggerPrefixes.length; j += 1) {
            const prefix = triggerPrefixes[j];
            registerShortcut("Summon " + appName + " via " + prefix, "Summon " + appName, prefix + "," + key, function () {
                summonApp(appName, false);
            });
        }
    }
}

function registerRegionShortcuts() {
    const regionBindings = {
        M: "main",
        W: "wide",
        S: "side",
        C: "chat",
        E: "center",
        L: "left",
        R: "right",
        T: "top_right",
        B: "bottom_right",
        F: "full",
    };
    const keys = objectKeys(regionBindings);
    for (let i = 0; i < keys.length; i += 1) {
        const key = keys[i];
        const regionName = regionBindings[key];
        registerShortcut("Move Active to Region " + regionName, "Move active window to " + regionName, "Meta+U," + key, function () {
            moveActiveToRegion(regionName);
        });
    }
    for (let cell = 1; cell <= 6; cell += 1) {
        registerShortcut("Move Active to Cell " + cell, "Move active window to layout cell " + cell, "Meta+U," + cell, function () {
            moveActiveToCell(cell);
        });
    }
}

function registerWorkflowShortcuts() {
    registerShortcut("Move Active Window to Next Screen", "Move active window to next screen", "Meta+O", function () {
        moveActiveToOutput("next");
    });
    registerShortcut("Move Active Window to Previous Screen", "Move active window to previous screen", "Meta+Shift+O", function () {
        moveActiveToOutput("previous");
    });
    registerShortcut("Cycle Active Screen Layout", "Cycle active screen layout", "Meta+Alt+Ctrl+Shift+P", cycleLayout);
    registerShortcut("Cycle Active Screen Layout Semicolon", "Cycle active screen layout", "Meta+Alt+Ctrl+Shift+;", cycleLayout);
    registerShortcut("Reset Active Screen Layout Apostrophe", "Reset active screen layout", "Meta+Alt+Ctrl+Shift+'", resetLayout);
    registerShortcut("Reload Plasma Summon Configuration Hyper", "Reload KWin configuration", "Meta+Alt+Ctrl+Shift+R", function () {
        loadRemoteConfig();
        callDBus("org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure", function () {});
    });
}

function cleanupPendingLaunches(now) {
    const names = objectKeys(state.pendingLaunches);
    for (let i = 0; i < names.length; i += 1) {
        const appName = names[i];
        const pending = state.pendingLaunches[appName];
        if (!pending || pending.expiresAt < now) {
            delete state.pendingLaunches[appName];
        }
    }
}

function handleWindowAdded(window) {
    if (!normalWindow(window)) {
        return;
    }
    const now = Date.now();
    cleanupPendingLaunches(now);
    const appName = appForWindow(window);
    if (!appName) {
        return;
    }
    const pending = state.pendingLaunches[appName];
    if (!pending) {
        return;
    }
    delete state.pendingLaunches[appName];
    state.lastByApp[appName] = windowId(window);
    if (pending.place) {
        placeAppWindow(appName, window);
    } else {
        focusWindow(window);
    }
}

workspace.windowActivated.connect(function (window) {
    if (state.activeWindow && state.activeWindow !== window) {
        state.previousWindow = state.activeWindow;
    }
    state.activeWindow = window;
    handleWindowAdded(window);
});

if (workspace.windowAdded) {
    workspace.windowAdded.connect(handleWindowAdded);
} else if (workspace.clientAdded) {
    workspace.clientAdded.connect(handleWindowAdded);
}

registerAppShortcuts();
registerRegionShortcuts();
registerWorkflowShortcuts();
loadRemoteConfig();
log("loaded");
