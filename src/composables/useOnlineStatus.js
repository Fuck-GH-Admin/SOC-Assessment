import { ref, onMounted, onUnmounted } from 'vue'

export function useOnlineStatus() {
  const online = ref(navigator.onLine)

  function updateOnline() { online.value = navigator.onLine }

  onMounted(() => {
    window.addEventListener('online', updateOnline)
    window.addEventListener('offline', updateOnline)
  })
  onUnmounted(() => {
    window.removeEventListener('online', updateOnline)
    window.removeEventListener('offline', updateOnline)
  })

  return { online }
}
