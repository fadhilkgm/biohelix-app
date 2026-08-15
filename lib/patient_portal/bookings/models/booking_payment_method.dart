enum BookingPaymentMethod { online, payOnArrival }

extension BookingPaymentMethodStatus on BookingPaymentMethod {
  String get paymentStatus => switch (this) {
    BookingPaymentMethod.online => 'paid',
    BookingPaymentMethod.payOnArrival => 'pay_at_collection',
  };
}
