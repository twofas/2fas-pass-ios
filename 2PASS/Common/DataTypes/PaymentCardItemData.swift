public typealias PaymentCardItemData = _ItemData<PaymentCardContent>

public struct PaymentCardContent: ItemContent, CustomDebugStringConvertible {

    public static let contentType: ItemContentType = .paymentCard
    public static let contentVersion = 1

    public let name: String?
    public let cardHolder: String?
    public let cardIssuer: String?
    public let cardNumber: Data?
    public let cardNumberMask: String?
    public let expirationDate: Data?
    public let securityCode: Data?
    public let notes: String?

    public var debugDescription: String {
        "PaymentCardContent(name: \(name ?? "nil"), cardHolder: <redacted>, cardIssuer: \(cardIssuer ?? "nil"), cardNumber: <redacted>, cardNumberMask: \(cardNumberMask ?? "nil"), expirationDate: <redacted>, securityCode: <redacted>, notes: \(notes == nil ? "nil" : "<redacted>"))"
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case cardHolder
        case cardNumber = "s_cardNumber"
        case expirationDate = "s_expirationDate"
        case securityCode = "s_securityCode"
        case notes
        case cardNumberMask
        case cardIssuer
    }

    public init(
        name: String?,
        cardHolder: String?,
        cardIssuer: String?,
        cardNumber: Data?,
        cardNumberMask: String?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?
    ) {
        self.name = name
        self.cardHolder = cardHolder
        self.cardNumber = cardNumber
        self.expirationDate = expirationDate
        self.securityCode = securityCode
        self.notes = notes
        self.cardNumberMask = cardNumberMask
        self.cardIssuer = cardIssuer
    }
}

extension ItemData {

    public var asPaymentCard: PaymentCardItemData? {
        switch self {
        case .paymentCard(let paymentCardItem): paymentCardItem
        default: nil
        }
    }
}
