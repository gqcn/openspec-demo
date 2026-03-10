import type { VxeGridPropTypes } from '@vben/plugins/vxe-table';

import type { FormSchemaGetter } from '#/adapter/form';

export const querySchema: FormSchemaGetter = () => [
  {
    component: 'Input',
    fieldName: 'username',
    label: '用户名',
  },
];

export const columns: VxeGridPropTypes.Columns = [
  { field: 'id', title: 'ID', width: 60 },
  { field: 'username', title: '用户名', width: 150 },
  { field: 'uid', title: 'UID', width: 90 },
  {
    field: 'isAdmin',
    title: '角色',
    width: 90,
    slots: { default: 'role' },
  },
  {
    field: 'status',
    title: '状态',
    width: 90,
    slots: { default: 'status' },
  },
  { field: 'createdAt', title: '创建时间', width: 180 },
  {
    field: 'action',
    title: '操作',
    width: 200,
    fixed: 'right',
    slots: { default: 'action' },
  },
];

export const createSchema: FormSchemaGetter = () => [
  {
    component: 'Input',
    fieldName: 'username',
    label: '用户名',
    rules: 'required',
  },
  {
    component: 'InputPassword',
    fieldName: 'password',
    label: '密码',
    rules: 'required',
  },
  {
    component: 'RadioGroup',
    fieldName: 'isAdmin',
    label: '角色',
    defaultValue: 0,
    componentProps: {
      buttonStyle: 'solid',
      optionType: 'button',
      options: [
        { label: '普通用户', value: 0 },
        { label: '管理员', value: 1 },
      ],
    },
  },
];

export const editSchema: FormSchemaGetter = () => [
  {
    component: 'Input',
    fieldName: 'id',
    label: 'ID',
    dependencies: {
      triggerFields: ['id'],
      show: () => false,
    },
  },
  {
    component: 'Input',
    fieldName: 'username',
    label: '用户名',
    componentProps: {
      disabled: true,
    },
  },
  {
    component: 'InputPassword',
    fieldName: 'password',
    label: '密码',
    componentProps: {
      placeholder: '留空则不修改',
    },
  },
  {
    component: 'RadioGroup',
    fieldName: 'isAdmin',
    label: '角色',
    componentProps: {
      buttonStyle: 'solid',
      optionType: 'button',
      options: [
        { label: '普通用户', value: 0 },
        { label: '管理员', value: 1 },
      ],
    },
  },
];
