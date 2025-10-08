/**
 * Order status enumeration
 */
const OrderStatus = {
  PENDING: 'PENDING',
  CONFIRMED: 'CONFIRMED',
  PROCESSING: 'PROCESSING',
  SHIPPED: 'SHIPPED',
  DELIVERED: 'DELIVERED',
  CANCELLED: 'CANCELLED'
};

// Freeze to prevent modifications
Object.freeze(OrderStatus);

module.exports = OrderStatus;
