import "SimpleCarFactory"

transaction(capabilityRecipient: Address) {
    let capabilityReceiverRef: &{SimpleCarFactory.GarageCapabilityReceiverPublic}
    let capabilityToGive: Capability<&SimpleCarFactory.Garage>

    prepare(signer: auth(Storage, Capabilities) &Account) {

        // Grab a reference to the Capability receiver resource from the public capability
        // that should have been created and published with transaction 01
        let receiverAccountRef: &Account = getAccount(capabilityRecipient)
        self.capabilityReceiverRef = 
            receiverAccountRef.capabilities.borrow<&{SimpleCarFactory.GarageCapabilityReceiverPublic}>(SimpleCarFactory.garageCapabilityReceiverPublicPath) ??
            panic(
                "Unable to retrieve a valid &{SimpleCarFactory.GarageCapabilityReceiverPublic} at "
                .concat(SimpleCarFactory.garageCapabilityReceiverPublicPath.toString())
                .concat(" for account ")
                .concat(capabilityRecipient.toString())
            )
        
        // Create the capability to share to the receiver. NOTE: This capability is for a full &Garage reference
        self.capabilityToGive = signer.capabilities.storage.issue<&SimpleCarFactory.Garage>(SimpleCarFactory.garageStoragePath)
        
    }

    execute {
        // Deposit the Capability created in the recipient's Capability receiver resource using the reference
        self.capabilityReceiverRef.addGarageCapability(cap: self.capabilityToGive)

    }
}