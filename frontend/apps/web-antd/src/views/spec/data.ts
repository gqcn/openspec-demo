import type { VxeGridPropTypes } from '@vben/plugins/vxe-table';

import type { FormSchemaGetter } from '#/adapter/form';

export const querySchema: FormSchemaGetter = () => [
  {
    component: 'Input',
    fieldName: 'name',
    label: '规格名称',
  },
];

export const columns: VxeGridPropTypes.Columns = [
  { field: 'id', title: 'ID', minWidth: 60, sortable: true },
  { field: 'name', title: '名称', minWidth: 160, sortable: true },
  { field: 'cpu', title: 'CPU', minWidth: 100, sortable: true },
  { field: 'memory', title: '内存', minWidth: 100, sortable: true },
  { field: 'gpu', title: 'GPU 数量', minWidth: 90, sortable: true },
  { field: 'gpuType', title: 'GPU 型号', minWidth: 140 },
  { field: 'enabled', title: '状态', minWidth: 90, sortable: true, slots: { default: 'status' } },
  { field: 'createdAt', title: '创建时间', minWidth: 180, sortable: true },
  {
    field: 'action',
    title: '操作',
    minWidth: 200,
    fixed: 'right',
    slots: { default: 'action' },
  },
];

export const drawerSchema: FormSchemaGetter = () => [
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
    fieldName: 'name',
    label: '名称',
    rules: 'required',
  },
  {
    component: 'Input',
    fieldName: 'cpu',
    label: 'CPU',
    rules: 'required',
    componentProps: {
      placeholder: '如: 4',
    },
  },
  {
    component: 'Input',
    fieldName: 'memory',
    label: '内存',
    rules: 'required',
    componentProps: {
      placeholder: '如: 8Gi',
    },
  },
  {
    component: 'InputNumber',
    fieldName: 'gpu',
    label: 'GPU 数量',
    componentProps: {
      min: 0,
      max: 8,
    },
  },
  {
    component: 'Input',
    fieldName: 'gpuType',
    label: 'GPU 型号',
    componentProps: {
      placeholder: '如: nvidia.com/gpu',
    },
  },
];
