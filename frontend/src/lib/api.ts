const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000/api/v1';

export async function getProducts() {
  const res = await fetch(`${API_URL}/products`, { cache: 'no-store' });
  // Guard before .json() so a 5xx surfaces as a handled error banner instead of
  // returning a non-array that later breaks the {#each} in the dashboard.
  if (!res.ok) throw new Error('Failed to load products');
  return res.json();
}

export async function getOrders() {
  const res = await fetch(`${API_URL}/orders`, { cache: 'no-store' });
  if (!res.ok) throw new Error('Failed to load orders');
  return res.json();
}

export async function createOrder(productId: number, buyerEmail: string) {
  const res = await fetch(`${API_URL}/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ order: { product_id: productId, buyer_email: buyerEmail } })
  });
  if (!res.ok) {
    const error = await res.json();
    throw new Error(error.errors?.join(', ') || 'Failed to create order');
  }
  return res.json();
}

export async function getDownloadInfo(token: string) {
  const res = await fetch(`${API_URL}/downloads/${token}`, { cache: 'no-store' });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(errorText || 'Failed to fetch download info');
  }
  return res.json();
}

export async function triggerDownload(token: string) {
  const res = await fetch(`${API_URL}/downloads/${token}/trigger`, {
    method: 'POST'
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(errorText || 'Failed to trigger download');
  }
  return res.json();
}

export async function resendOrderLink(orderId: number) {
  const res = await fetch(`${API_URL}/orders/${orderId}/resend_link`, {
    method: 'POST'
  });
  if (!res.ok) {
    throw new Error('Failed to resend link');
  }
  return res.json();
}
