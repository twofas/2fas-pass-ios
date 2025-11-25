public typealias CardItemData = _ItemData<CardContent>

public struct CardContent: ItemContent {

    public static let contentType: ItemContentType = .card
    public static let contentVersion = 1

    public let name: String?
    public let cardHolder: String?
    public let cardIssuer: String?
    public let cardNumber: Data?
    public let cardNumberMask: String?
    public let expirationDate: Data?
    public let securityCode: Data?
    public let notes: String?

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

    public var asCard: CardItemData? {
        switch self {
        case .card(let cardItem): cardItem
        default: nil
        }
    }
}
