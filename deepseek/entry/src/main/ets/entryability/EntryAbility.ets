import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AuthStore } from '../store/AuthStore';
import { SettingsStore } from '../store/SettingsStore';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'DeepSeekApp', 'Ability onCreate');
    this.syncDarkModeFromConfig(this.context.config);
    this.initStores();
  }

  private async initStores(): Promise<void> {
    await SettingsStore.getInstance().ensureInit(this.context);
    SettingsStore.getInstance().applyColorMode(this.context);
    await AuthStore.getInstance().ensureInit(this.context);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    this.syncDarkModeFromConfig(newConfig);
  }

  private syncDarkModeFromConfig(config: Configuration | undefined): void {
    if (config !== undefined && config.colorMode !== undefined) {
      const isDark = config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      AppStorage.setOrCreate('isDarkMode', isDark);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'DeepSeekApp', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'DeepSeekApp', 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'DeepSeekApp', 'Failed to load the content. Code: %{public}d', err.code);
        return;
      }
      hilog.info(DOMAIN, 'DeepSeekApp', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'DeepSeekApp', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'DeepSeekApp', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'DeepSeekApp', 'Ability onBackground');
  }
}
