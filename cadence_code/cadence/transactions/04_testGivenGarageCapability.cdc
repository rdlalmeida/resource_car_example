import "SimpleCarFactory"

transaction() {
    let garagePrivateRef: &SimpleCarFactory.Garage
    let garageCapabilityReceiverRef: auth(Storage) &SimpleCarFactory.GarageCapabilityReceiver
    let signerAddress: Address

    prepare(signer: auth(Capabilities, Storage) &Account) {
        self.signerAddress = signer.address

        // Get an authorised reference to the Garage Capability Receiver for this account
        self.garageCapabilityReceiverRef = 
            signer
                .storage
                    .borrow<auth(Storage) &SimpleCarFactory.GarageCapabilityReceiver>(from: SimpleCarFactory.garageCapabilityReceiverStoragePath) ??
                    panic(
                        "Unable to get a valid &SimpleCarFactory.GarageCapabilityReceiver at "
                        .concat(SimpleCarFactory.garageCapabilityReceiverStoragePath.toString())
                        .concat(" from account ")
                        .concat(signer.address.toString())
                    )
        
        // Use the capability that should be contained in the receiver resource to grab
        // a Private reference to the Garage in the contract deployer's account
        self.garagePrivateRef = self.garageCapabilityReceiverRef.garageCapability!.borrow() ??
        panic(
            "Unable to get a private &SimpleCarFactory.Garage at "
            .concat(SimpleCarFactory.garageStoragePath.toString())
            .concat(" for account ")
            .concat(signer.address.toString())
        )
    }

    execute {
        let publicResponse: String = self.garagePrivateRef.testPublicCapability()
        let privateResponse: String = self.garagePrivateRef.testPrivateCapability()

        log(
            "Testing public capability: "
            .concat(publicResponse)
        )

        log(
            "Testing private capability: "
            .concat(privateResponse)
        )
    }
}