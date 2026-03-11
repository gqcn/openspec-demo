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
  copyright: {
    companyName: 'vben',
    companySiteLink: '',
    date: `${new Date().getFullYear()}`,
    enable: true,
  },
  footer: {
    enable: false,
  },
  tabbar: {
    persist: false,
  },
  theme: {
    semiDarkSidebar: false,
    radius: '0.375',
  },
});
