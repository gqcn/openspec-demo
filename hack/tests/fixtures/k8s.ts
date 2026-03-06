import { execSync } from 'node:child_process'
import { config } from './config'

/**
 * K8s helper — run kubectl commands against the test cluster.
 */
export function kubectl(args: string): string {
  try {
    return execSync(`kubectl -n ${config.k8sNamespace} ${args}`, {
      encoding: 'utf-8',
      timeout: 30_000,
    }).trim()
  } catch (e: any) {
    return e.stdout?.toString().trim() ?? e.message
  }
}

/**
 * Wait for a pod to be 1/1 Running.
 * Returns true if ready within timeout, false otherwise.
 */
export async function waitPodReady(
  podName: string,
  maxSeconds: number = config.podTimeout,
): Promise<boolean> {
  const iterations = Math.ceil(maxSeconds / 5)
  for (let i = 0; i < iterations; i++) {
    const output = kubectl(`get pod ${podName} --no-headers`)
    const parts = output.split(/\s+/)
    const ready = parts[1] ?? ''
    const status = parts[2] ?? ''
    if (status === 'Running' && ready === '1/1') return true
    await new Promise((r) => setTimeout(r, 5_000))
  }
  return false
}

/**
 * Execute a command inside a pod.
 */
export function execInPod(podName: string, command: string): string {
  return kubectl(`exec ${podName} -- /bin/bash -c "${command.replace(/"/g, '\\"')}"`)
}
