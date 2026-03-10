import { defineOverridesPreferences } from '@vben/preferences';

/**
 * @description Project configuration overrides
 */
export const overridesPreferences = defineOverridesPreferences({
  app: {
    accessMode: 'frontend',
    enableRefreshToken: false,
    defaultHomePath: '/notebooks',
    name: import.meta.env.VITE_APP_TITLE,
  },
  footer: {
    enable: false,
  },
  tabbar: {
    persist: false,
  },
  theme: {
    semiDarkSidebar: true,
    radius: '0.375',
  },
});
