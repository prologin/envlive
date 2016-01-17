# Hide some prompts
user_pref("browser.customizemode.tip0.shown", true);
user_pref("reader.parse-on-load.enabled", false);

# Choose downloads
user_pref("browser.download.useDownloadDir", false);

# Disable useless stuffs
user_pref("signon.rememberSignons", false);
user_pref("browser.search.update", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.toolbarbuttons.introduced.pocket-button", true);
user_pref("experiments.activeExperiment", false);

# Homepage
user_pref("browser.startup.homepage", "http://192.168.56.1:8081/");

# Don't open "welcome" tabs
user_pref("browser.startup.homepage_override.mstone", "ignore");

# UI buttons
user_pref("browser.uiCustomization.state", "{\"placements\":{\"PanelUI-contents\":[\"edit-controls\",\"zoom-controls\",\"new-window-button\",\"privatebrowsing-button\",\"find-button\",\"downloads-button\",\"history-panelmenu\",\"preferences-button\"],\"addon-bar\":[\"addonbar-closebutton\",\"status-bar\"],\"PersonalToolbar\":[\"personal-bookmarks\"],\"nav-bar\":[\"urlbar-container\",\"home-button\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"toolbar-menubar\":[\"menubar-items\"]},\"seen\":[],\"dirtyAreaCache\":[\"PersonalToolbar\",\"nav-bar\",\"TabsToolbar\",\"toolbar-menubar\",\"PanelUI-contents\",\"addon-bar\"],\"currentVersion\":4,\"newElementCount\":0}");

# Disable reporting bullshit
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("toolkit.telemetry.prompted", 2);
user_pref("toolkit.telemetry.rejected", true);
user_pref("toolkit.telemetry.enabled", false);
user_pref("datareporting.healthreport.service.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.healthreport.service.firstRun", false);
user_pref("datareporting.healthreport.logging.consoleEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.policy.dataSubmissionPolicyResponseType", "accepted-info-bar-dismissed");
user_pref("datareporting.policy.dataSubmissionPolicyAccepted", false);

