// Hide some prompts
user_pref("reader.parse-on-load.enabled", false);

// Choose downloads
user_pref("browser.download.useDownloadDir", false);

// Disable useless stuffs
user_pref("browser.search.update", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("extensions.pocket.enabled", false);
user_pref("browser.newtabpage.enabled", false);

// Homepage
user_pref("browser.startup.homepage", "https://prologin.org/");

// Don't open "welcome" tabs
user_pref("browser.startup.homepage_override.mstone", "ignore");

// UI buttons
user_pref("browser.uiCustomization.state", "{\"placements\":{\"PanelUI-contents\":[\"edit-controls\",\"zoom-controls\",\"new-window-button\",\"privatebrowsing-button\",\"find-button\",\"downloads-button\",\"history-panelmenu\",\"preferences-button\"],\"addon-bar\":[\"addonbar-closebutton\",\"status-bar\"],\"PersonalToolbar\":[\"personal-bookmarks\"],\"nav-bar\":[\"urlbar-container\",\"home-button\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"toolbar-menubar\":[\"menubar-items\"]},\"seen\":[],\"dirtyAreaCache\":[\"PersonalToolbar\",\"nav-bar\",\"TabsToolbar\",\"toolbar-menubar\",\"PanelUI-contents\",\"addon-bar\"],\"currentVersion\":4,\"newElementCount\":0}");

// Disable reporting bullshit
// See https://firefox-source-docs.mozilla.org/toolkit/components/telemetry/internals/preferences.html
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);

// Use a private browser window
user_pref("browser.privatebrowsing.autostart", true);
