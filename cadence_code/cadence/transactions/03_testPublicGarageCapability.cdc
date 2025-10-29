import "SimpleCarFactory"

transaction() {
    let garagePublicRef: &{SimpleCarFactory.PublicGarage}
    let signerAddress: Address

    prepare(signer: auth(Capabilities) &Account) {
        self.signerAddress = signer.address

        self.garagePublicRef = signer.capabilities.borrow<&{SimpleCarFactory.PublicGarage}>(SimpleCarFactory.garagePublicPath) ??
        panic(
            "Unable to retrieve a valid &{SimpleCarFactory.PublicGarage} at "
            .concat(SimpleCarFactory.garagePublicPath.toString())
            .concat(" for account ")
            .concat(signer.address.toString())
        )
    }

    execute {
        let publicResponse: String? = self.garagePublicRef.testPublicCapability()

        if (publicResponse != nil) {
            log(
                "Testing public garage capability: "
                .concat(publicResponse!)
            )
        }
        else {
            log(
                "Cannot access account "
                .concat(self.signerAddress.toString())
                .concat(" public Garage capability.")
                )
        }
    }
}