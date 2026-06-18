<script lang="ts">
  import { onMount } from 'svelte';
  import { getProducts, getOrders, createOrder, resendOrderLink } from '$lib/api';

  let products: any[] = $state([]);
  let orders: any[] = $state([]);
  let selectedProductId: number | null = $state(null);
  let buyerEmail = $state('');
  let creating = $state(false);
  let orderResult: any = $state(null);
  let orderError: string | null = $state(null);
  let loadingData = $state(true);
  let fetchError: string | null = $state(null);

  async function loadData() {
    loadingData = true;
    fetchError = null;
    try {
      products = await getProducts();
      orders = await getOrders();
      if (products.length > 0 && !selectedProductId) {
        selectedProductId = products[0].id;
      }
    } catch (err: any) {
      fetchError = err.message || 'Network error occurred';
    } finally {
      loadingData = false;
    }
  }

  onMount(() => {
    loadData();
  });

  async function handleOrder(e: Event) {
    e.preventDefault();
    if (!selectedProductId || !buyerEmail) return;
    
    creating = true;
    orderError = null;
    orderResult = null;
    
    try {
      orderResult = await createOrder(selectedProductId, buyerEmail);
      await loadData(); // Refresh orders
      buyerEmail = '';
    } catch (err: any) {
      orderError = err.message;
    } finally {
      creating = false;
    }
  }

  async function handleResend(orderId: number) {
    try {
      const updatedOrder = await resendOrderLink(orderId);
      orders = orders.map(o => o.id === orderId ? updatedOrder : o);
      orderResult = updatedOrder;
      orderError = null;
    } catch (err: any) {
      alert("Failed to resend link");
    }
  }
</script>

<main class="container">
  <h1>SendOwl Dashboard</h1>

  <section class="card">
    <h2>Products</h2>
    {#if loadingData}
      <p>Loading data...</p>
    {:else if fetchError}
      <p class="error">Error loading data: {fetchError}. Please make sure the Rails server is running on port 3000.</p>
    {:else}
      <ul>
        {#each products as product}
          <li>
            <strong>{product.name}</strong> 
            (Expires: {product.expiry_hours < 1 ? Math.round(product.expiry_hours * 60) + 'm' : product.expiry_hours + 'h'}, Max downloads: {product.max_download_count})
          </li>
        {/each}
        {#if products.length === 0}
          <li>No products found. Run rails db:seed.</li>
        {/if}
      </ul>
    {/if}
  </section>

  <section class="card">
    <h2>Simulate Purchase</h2>
    <form onsubmit={handleOrder}>
      <div>
        <label for="product">Product:</label>
        <select id="product" bind:value={selectedProductId}>
          {#each products as product}
            <option value={product.id}>{product.name}</option>
          {/each}
        </select>
      </div>
      <div>
        <label for="email">Buyer Email:</label>
        <input id="email" type="email" bind:value={buyerEmail} required />
      </div>
      <button type="submit" disabled={creating}>
        {creating ? 'Processing...' : 'Complete Purchase'}
      </button>
    </form>
    
    {#if orderError}
      <p class="error">{orderError}</p>
    {/if}
    
    {#if orderResult}
      <div class="success">
        <p>Order created for {orderResult.buyer_email}!</p>
        <p>Check your email ({orderResult.buyer_email}) for the download link.</p>
      </div>
    {/if}
  </section>

  <section class="card">
    <h2>Recent Orders & Download Links</h2>
    <table>
      <thead>
        <tr>
          <th>ID</th>
          <th>Product</th>
          <th>Buyer Email</th>
          <th>Link Expires At</th>
          <th>Downloads</th>
          <th>Status</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        {#each orders as order}
          <tr>
            <td>{order.id}</td>
            <td>{order.product.name}</td>
            <td>{order.buyer_email}</td>
            <td>{new Date(order.download_link.expires_at).toLocaleString()}</td>
            <td>{order.download_link.download_count} / {order.product.max_download_count}</td>
            <td>
              {#if new Date() > new Date(order.download_link.expires_at)}
                <span class="badge expired">Expired</span>
              {:else if order.download_link.download_count >= order.product.max_download_count}
                <span class="badge limit">Limit Reached</span>
              {:else}
                <span class="badge active">Active</span>
              {/if}
            </td>
            <td>
              <button 
                onclick={() => handleResend(order.id)} 
                class="btn-small"
                disabled={order.download_link.download_count >= order.product.max_download_count || new Date() > new Date(order.download_link.expires_at)}
              >
                Resend Link
              </button>
            </td>
          </tr>
        {/each}
        {#if orders.length === 0}
          <tr>
            <td colspan="7">No orders yet.</td>
          </tr>
        {/if}
      </tbody>
    </table>
  </section>
</main>

<style>
  :global(body) {
    font-family: system-ui, -apple-system, sans-serif;
    background: #f4f4f5;
    color: #18181b;
    margin: 0;
    padding: 20px;
  }
  .container {
    max-width: 1000px;
    margin: 0 auto;
  }
  .card {
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    margin-bottom: 20px;
  }
  h1, h2 {
    margin-top: 0;
  }
  form {
    display: flex;
    flex-direction: column;
    gap: 15px;
    max-width: 400px;
  }
  input, select {
    padding: 8px;
    border: 1px solid #d4d4d8;
    border-radius: 4px;
    width: 100%;
    margin-top: 4px;
  }
  button {
    background: #2563eb;
    color: white;
    padding: 10px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }
  button:disabled {
    opacity: 0.5;
  }
  .btn-small {
    padding: 6px 10px;
    font-size: 0.85em;
  }
  .error { color: #dc2626; }
  .success {
    background: #dcfce7;
    color: #166534;
    padding: 10px;
    border-radius: 4px;
    margin-top: 15px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
  }
  th, td {
    text-align: left;
    padding: 10px;
    border-bottom: 1px solid #e4e4e7;
  }
  .badge {
    padding: 4px 8px;
    border-radius: 99px;
    font-size: 0.8em;
    font-weight: 600;
  }
  .badge.active { background: #dcfce7; color: #166534; }
  .badge.expired { background: #fee2e2; color: #991b1b; }
  .badge.limit { background: #fef9c3; color: #854d0e; }
  a {
    color: #2563eb;
    text-decoration: none;
  }
</style>
