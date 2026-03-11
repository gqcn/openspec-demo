<script lang="ts" setup>
import { onMounted, ref } from 'vue';

import { useVbenModal } from '@vben/common-ui';

import { Card, Col, message, Row, Select, SelectOption } from 'ant-design-vue';

import { type ImageItem, imageList } from '#/api/image';
import { notebookCreate } from '#/api/notebook';
import { type Spec, specList } from '#/api/spec';

const emit = defineEmits<{ reload: [] }>();

const specs = ref<Spec[]>([]);
const images = ref<ImageItem[]>([]);
const selectedSpecId = ref<null | number>(null);
const selectedImage = ref('');

const [Modal, modalApi] = useVbenModal({
  async onConfirm() {
    if (!selectedSpecId.value) {
      message.warning('请选择规格');
      return;
    }
    if (!selectedImage.value) {
      message.warning('请选择镜像');
      return;
    }

    modalApi.setState({ confirmLoading: true });
    try {
      await notebookCreate({
        specId: selectedSpecId.value,
        imageKey: selectedImage.value,
      });
      message.success('开发机创建中，请稍候...');
      emit('reload');
      modalApi.close();
    } catch {
      // 错误已由请求拦截器统一提示
    } finally {
      modalApi.setState({ confirmLoading: false });
    }
  },
  onOpenChange(isOpen: boolean) {
    if (isOpen) {
      selectedSpecId.value = null;
      selectedImage.value = '';
    }
  },
});

onMounted(async () => {
  const [specRes, imageRes] = await Promise.all([
    specList(1, 1000),
    imageList(),
  ]);
  specs.value = (specRes.list || []).filter((s: Spec) => s.enabled === 1);
  images.value = imageRes || [];
});
</script>

<template>
  <Modal class="w-[680px]" title="创建开发机">
    <div style="margin-bottom: 16px">
      <div style="font-weight: 600; margin-bottom: 12px; color: #303133">
        选择规格
      </div>
      <Row :gutter="12">
        <Col v-for="spec in specs" :key="spec.id" :span="12">
          <Card
            :bordered="true"
            :class="[
              'spec-card',
              selectedSpecId === spec.id ? 'spec-card-selected' : '',
            ]"
            hoverable
            size="small"
            style="margin-bottom: 12px; cursor: pointer"
            @click="selectedSpecId = spec.id"
          >
            <div style="font-weight: 600; font-size: 15px; color: #303133">
              {{ spec.name }}
            </div>
            <div style="margin-top: 6px; color: #606266; font-size: 13px">
              <span>CPU: {{ spec.cpu }} Cores</span>
              <span style="margin: 0 8px"
                >内存: {{ String(spec.memory).replace(/Gi$/i, '') }} Gi</span
              >
            </div>
            <div
              v-if="spec.gpu > 0"
              style="color: #606266; font-size: 13px; margin-top: 2px"
            >
              GPU: {{ spec.gpu }}x {{ spec.gpuType }}
            </div>
            <div
              v-else
              style="color: #909399; font-size: 13px; margin-top: 2px"
            >
              无 GPU
            </div>
          </Card>
        </Col>
      </Row>
    </div>

    <div>
      <div style="font-weight: 600; margin-bottom: 12px; color: #303133">
        选择镜像
      </div>
      <Select
        v-model:value="selectedImage"
        placeholder="请选择镜像"
        size="large"
        style="width: 100%"
      >
        <SelectOption
          v-for="img in images"
          :key="img.key"
          :value="img.key"
        >
          <div>
            <span style="font-weight: 600">{{ img.name }}</span>
            <span
              v-if="img.description"
              style="color: #909399; font-size: 12px; margin-left: 8px"
            >
              {{ img.description }}
            </span>
          </div>
        </SelectOption>
      </Select>
    </div>
  </Modal>
</template>

<style scoped>
.spec-card {
  border: 2px solid #e4e7ed;
  border-radius: 8px;
  transition: all 0.2s;
}

.spec-card:hover {
  border-color: var(--ant-color-primary);
}

.spec-card-selected {
  border-color: var(--ant-color-primary);
  background: var(--ant-color-primary-bg);
}
</style>
