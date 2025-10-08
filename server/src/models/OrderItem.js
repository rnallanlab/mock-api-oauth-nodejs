/**
 * Represents an item within an order
 */
class OrderItem {
  constructor(productId, productName, quantity, unitPrice) {
    this.productId = productId;
    this.productName = productName;
    this.quantity = quantity;
    this.unitPrice = unitPrice;
  }
}

module.exports = OrderItem;
