/**
 * Response model for paginated orders list
 */
class OrdersResponse {
  constructor(orders, totalCount, limit, offset) {
    this.orders = orders;
    this.totalCount = totalCount;
    this.limit = limit;
    this.offset = offset;
  }
}

module.exports = OrdersResponse;
