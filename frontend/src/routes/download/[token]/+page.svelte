<script lang="ts">
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import { getDownloadInfo, triggerDownload } from '$lib/api';

  let token = $state($page.params.token);
  let info: any = $state(null);
  let loading = $state(true);
  let fetchError: string | null = $state(null);
  let downloading = $state(false);
  let downloadError: string | null = $state(null);

  onMount(async () => {
    try {
      info = await getDownloadInfo(token);
    } catch (err: any) {
      fetchError = err.message;
    } finally {
      loading = false;
    }
  });

  async function handleDownload() {
    downloading = true;
    downloadError = null;
    try {
      const result = await triggerDownload(token);
      if (result.file_url) {
        window.location.href = result.file_url;
      }
    } catch (err: any) {
      downloadError = err.message;
    } finally {
      downloading = false;
    }
  }
</script>

<main class="container">
  <section class="card text-center">
    {#if loading}
      <p>Loading your secure link...</p>
    {:else if fetchError}
      <h2 class="error">Access Denied</h2>
      <p>{fetchError}</p>
    {:else if info.expired}
      <!-- show#GET returns 200 with these flags so we can explain *why* the link is dead,
           instead of just disabling the button with no context. -->
      <h2 class="error">Link Expired</h2>
      <p>The download link for <strong>{info.product_name}</strong> expired on
        {new Date(info.expires_at).toLocaleString()} and can no longer be used.</p>
      <p class="hint">Need access again? Contact the merchant to request a new link.</p>
    {:else if info.limit_reached}
      <h2 class="error">Download Limit Reached</h2>
      <p>The download link for <strong>{info.product_name}</strong> has already been used
        the maximum number of times.</p>
      <p class="hint">Need access again? Contact the merchant to request a new link.</p>
    {:else}
      <h2>Download Ready</h2>
      <p>Your product <strong>{info.product_name}</strong> is ready for download.</p>

      <div class="stats">
        <p>Downloads remaining: <strong>{info.remaining_downloads}</strong></p>
      </div>

      <button onclick={handleDownload} disabled={downloading} class="download-btn">
        {downloading ? 'Preparing Download...' : 'Download Now'}
      </button>

      {#if downloadError}
        <!-- Covers the race where the limit is hit concurrently after the page loaded:
             the POST returns 403 and we surface it here. -->
        <p class="error mt-4">{downloadError}</p>
      {/if}
    {/if}
  </section>
</main>

<style>
  :global(body) {
    font-family: system-ui, -apple-system, sans-serif;
    background: #f4f4f5;
    color: #18181b;
    margin: 0;
    padding: 40px 20px;
  }
  .container {
    max-width: 600px;
    margin: 0 auto;
  }
  .card {
    background: white;
    padding: 40px;
    border-radius: 8px;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  }
  .text-center {
    text-align: center;
  }
  h2 {
    margin-top: 0;
    color: #111827;
  }
  .error { color: #dc2626; }
  .hint {
    color: #6b7280;
    font-size: 0.9em;
    margin-top: 12px;
  }
  .stats {
    background: #f3f4f6;
    padding: 15px;
    border-radius: 6px;
    margin: 20px 0;
    display: inline-block;
  }
  .download-btn {
    background: #2563eb;
    color: white;
    padding: 12px 24px;
    font-size: 1.1em;
    font-weight: 600;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    transition: background-color 0.2s;
  }
  .download-btn:hover:not(:disabled) {
    background: #1d4ed8;
  }
  .download-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .mt-4 {
    margin-top: 16px;
  }
</style>
