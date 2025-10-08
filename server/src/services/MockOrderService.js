const Order = require('../models/Order');
const OrderItem = require('../models/OrderItem');
const OrderStatus = require('../models/OrderStatus');

/**
 * Service for generating and managing mock order data
 */
class MockOrderService {
  constructor() {
    this.mockOrders = this.generateMockOrders();
    console.log(`Generated ${this.mockOrders.length} mock orders`);
  }

  generateMockOrders() {
    const orders = [];
    const customerIds = ['CUST12345', 'CUST67890', 'CUST11111', 'CUST22222', 'CUST33333'];
    const productIds = ['PROD001', 'PROD002', 'PROD003', 'PROD004', 'PROD005', 'PROD006'];
    const productNames = ['Widget A', 'Widget B', 'Gadget X', 'Gadget Y', 'Tool Z', 'Device Q'];
    const statuses = Object.values(OrderStatus);

    // Generate orders for the past 2 years
    const now = new Date();
    const startDate = new Date(now);
    startDate.setDate(startDate.getDate() - 730); // 2 years ago

    for (let i = 0; i < 100; i++) {
      const customerId = customerIds[i % customerIds.length];
      const orderId = `ORD${String(i + 1).padStart(5, '0')}`;

      // Random date within the past 2 years
      const dayOffset = Math.floor(Math.random() * 730);
      const hourOffset = Math.floor(Math.random() * 24);
      const orderDate = new Date(startDate);
      orderDate.setDate(orderDate.getDate() + dayOffset);
      orderDate.setHours(orderDate.getHours() + hourOffset);

      // Random status
      const status = statuses[Math.floor(Math.random() * statuses.length)];

      // Generate 1-5 order items
      const itemCount = 1 + Math.floor(Math.random() * 5);
      const items = [];
      let totalAmount = 0.0;

      for (let j = 0; j < itemCount; j++) {
        const productIndex = Math.floor(Math.random() * productIds.length);
        const quantity = 1 + Math.floor(Math.random() * 5);
        let unitPrice = 10.0 + (Math.random() * 190.0); // $10-$200
        unitPrice = Math.round(unitPrice * 100) / 100; // Round to 2 decimals

        items.push(new OrderItem(
          productIds[productIndex],
          productNames[productIndex],
          quantity,
          unitPrice
        ));

        totalAmount += quantity * unitPrice;
      }

      totalAmount = Math.round(totalAmount * 100) / 100;

      orders.push(new Order(
        orderId,
        customerId,
        orderDate.toISOString(),
        status,
        totalAmount,
        'USD',
        items
      ));
    }

    return orders;
  }

  findOrdersByCustomerId(customerId, startDate, endDate, limit, offset) {
    console.log(`Finding orders for customerId=${customerId}, startDate=${startDate}, endDate=${endDate}, limit=${limit}, offset=${offset}`);

    let startInstant = startDate ? new Date(startDate) : null;
    let endInstant = endDate ? new Date(endDate) : null;
    if (endInstant) {
      endInstant.setDate(endInstant.getDate() + 1); // Add 1 day for exclusive end
    }

    return this.mockOrders
      .filter(order => order.customerId === customerId)
      .filter(order => !startInstant || new Date(order.orderDate) >= startInstant)
      .filter(order => !endInstant || new Date(order.orderDate) < endInstant)
      .sort((o1, o2) => new Date(o2.orderDate) - new Date(o1.orderDate)) // Newest first
      .slice(offset, offset + limit);
  }

  countOrdersByCustomerId(customerId, startDate, endDate) {
    let startInstant = startDate ? new Date(startDate) : null;
    let endInstant = endDate ? new Date(endDate) : null;
    if (endInstant) {
      endInstant.setDate(endInstant.getDate() + 1);
    }

    return this.mockOrders
      .filter(order => order.customerId === customerId)
      .filter(order => !startInstant || new Date(order.orderDate) >= startInstant)
      .filter(order => !endInstant || new Date(order.orderDate) < endInstant)
      .length;
  }

  findOrderById(orderId) {
    console.log(`Finding order by orderId=${orderId}`);
    return this.mockOrders.find(order => order.orderId === orderId) || null;
  }
}

module.exports = MockOrderService;
