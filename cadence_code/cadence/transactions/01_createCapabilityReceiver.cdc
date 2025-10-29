import "SimpleCarFactory"

transaction() {
    prepare(signer: auth(Capabilities, Storage) &Account) {
        // Get a new Garage Capability Receiver resource
        let newGarageCapReceiver: @SimpleCarFactory.GarageCapabilityReceiver <- SimpleCarFactory.createGarageCapabilityReceiver()

        // Save the Capability Receiver to storage
        signer.storage.save(<- newGarageCapReceiver, to: SimpleCarFactory.garageCapabilityReceiverStoragePath)

        // Create and publish a public capability to the capability receiver (which is a resource, not a capability itself!)
        let garageCapReceiverPublic: Capability<&{SimpleCarFactory.GarageCapabilityReceiverPublic}> = signer.capabilities.storage.issue<&{SimpleCarFactory.GarageCapabilityReceiverPublic}>(SimpleCarFactory.garageCapabilityReceiverStoragePath)
        signer.capabilities.publish(garageCapReceiverPublic, at: SimpleCarFactory.garageCapabilityReceiverPublicPath)

        // Done
    }

    execute  {

    }
}