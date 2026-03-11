import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    meta: {
      icon: 'lucide:monitor',
      order: 1,
      title: 'Notebook',
    },
    name: 'Notebooks',
    path: '/notebooks',
    component: () => import('#/views/notebook/index.vue'),
  },
  {
    meta: {
      icon: 'lucide:cpu',
      order: 2,
      title: '规格管理',
      authority: ['admin'],
    },
    name: 'SpecManage',
    path: '/specs',
    component: () => import('#/views/spec/index.vue'),
  },
  {
    meta: {
      icon: 'lucide:users',
      order: 3,
      title: '用户管理',
      authority: ['admin'],
    },
    name: 'UserManage',
    path: '/users',
    component: () => import('#/views/user/index.vue'),
  },
];

export default routes;
