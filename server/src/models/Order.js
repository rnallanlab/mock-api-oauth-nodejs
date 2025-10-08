/**
 * Represents an order in the system
 */
class Order {
  constructor(orderId, customerId, orderDate, status, totalAmount, currency, items) {
    this.orderId = orderId;
    this.customerId = customerId;
    this.orderDate = orderDate; // ISO 8601 string or Date object
    this.status = status;
    this.totalAmount = totalAmount;
    this.currency = currency;
    this.items = items;
  }
}

module.exports = Order;
