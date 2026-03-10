<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { listSpecs, type Spec } from '@/api/spec'
import { listImages, type ImageItem } from '@/api/image'
import { createNotebook } from '@/api/notebook'
import { ElMessage } from 'element-plus'

const props = defineProps<{ visible: boolean }>()
const emit = defineEmits<{
  (e: 'update:visible', v: boolean): void
  (e: 'created'): void
}>()

const specs = ref<Spec[]>([])
const images = ref<ImageItem[]>([])
const selectedSpecId = ref<number | null>(null)
const selectedImage = ref('')
const loading = ref(false)

onMounted(async () => {
  const [sr, ir] = await Promise.all([listSpecs(1, 1000), listImages()])
  specs.value = (sr.data || []).filter((s: Spec) => s.enabled === 1)
  images.value = ir.data || []
})

async function handleCreate() {
  if (!selectedSpecId.value) return ElMessage.warning('请选择规格')
  if (!selectedImage.value) return ElMessage.warning('请选择镜像')
  loading.value = true
  try {
    await createNotebook({ specId: selectedSpecId.value, imageKey: selectedImage.value })
    ElMessage.success('开发机创建中，请稍候...')
    emit('created')
    emit('update:visible', false)
  } catch (e: any) {
    ElMessage.error(e?.message || '创建失败')
  } finally {
    loading.value = false
  }
}

function specCardClass(spec: Spec) {
  return ['spec-card', selectedSpecId.value === spec.id ? 'selected' : '']
}
</script>

<template>
  <el-dialog
    :model-value="visible"
    title="创建开发机"
    width="680px"
    :close-on-click-modal="false"
    @update:model-value="emit('update:visible', $event)"
  >
    <div style="margin-bottom: 16px">
      <div style="font-weight: 600; margin-bottom: 12px; color: #303133">选择规格</div>
      <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px">
        <div
          v-for="spec in specs"
          :key="spec.id"
          :class="specCardClass(spec)"
          @click="selectedSpecId = spec.id"
        >
          <div style="font-weight: 600; font-size: 15px; color: #303133">{{ spec.name }}</div>
          <div style="margin-top: 6px; color: #606266; font-size: 13px">
            <span>CPU: {{ spec.cpu }}</span>
            <span style="margin: 0 8px">内存: {{ spec.memory }}</span>
          </div>
          <div v-if="spec.gpu > 0" style="color: #606266; font-size: 13px; margin-top: 2px">
            GPU: {{ spec.gpu }}x {{ spec.gpuType }}
          </div>
          <div v-else style="color: #909399; font-size: 13px; margin-top: 2px">无 GPU</div>
        </div>
      </div>
    </div>

    <div>
      <div style="font-weight: 600; margin-bottom: 12px; color: #303133">选择镜像</div>
      <el-select v-model="selectedImage" placeholder="请选择镜像" style="width: 100%" size="large">
        <el-option
          v-for="img in images"
          :key="img.key"
          :label="img.name"
          :value="img.key"
        >
          <div>
            <span style="font-weight: 600">{{ img.name }}</span>
            <span v-if="img.description" style="color: #909399; font-size: 12px; margin-left: 8px">{{ img.description }}</span>
          </div>
        </el-option>
      </el-select>
    </div>

    <template #footer>
      <el-button @click="emit('update:visible', false)">取消</el-button>
      <el-button type="primary" :loading="loading" @click="handleCreate">创建</el-button>
    </template>
  </el-dialog>
</template>

<style scoped>
.spec-card {
  border: 2px solid #e4e7ed;
  border-radius: 8px;
  padding: 14px 16px;
  cursor: pointer;
  transition: all 0.2s;
}
.spec-card:hover {
  border-color: #409eff;
  background: #f0f7ff;
}
.spec-card.selected {
  border-color: #409eff;
  background: #ecf5ff;
}
</style>
