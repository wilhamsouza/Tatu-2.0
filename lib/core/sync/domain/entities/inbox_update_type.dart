enum InboxUpdateType {
  categorySnapshot('category_snapshot'),
  productSnapshot('product_snapshot'),
  variantSnapshot('variant_snapshot'),
  priceSnapshot('price_snapshot'),
  customerMergeOrEnrichment('customer_merge_or_enrichment');

  const InboxUpdateType(this.wireValue);

  final String wireValue;

  static InboxUpdateType fromWireValue(String value) {
    return InboxUpdateType.values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () => InboxUpdateType.productSnapshot,
    );
  }
}
