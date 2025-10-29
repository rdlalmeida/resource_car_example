import "SimpleCarFactory"

transaction() {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // let oldGarage: @{SimpleCarFactory.PublicGarage}? <- signer.storage.load<@{SimpleCarFactory.PublicGarage}>(from: SimpleCarFactory.garageStoragePath)
        // destroy oldGarage

        let newGarage: @{SimpleCarFactory.PublicGarage} <- SimpleCarFactory.createGarage()

        signer.storage.save(<- newGarage, to: SimpleCarFactory.garageStoragePath)

        let garagePublicCapability: Capability<&{SimpleCarFactory.PublicGarage}> =
            signer.capabilities.storage.issue<&{SimpleCarFactory.PublicGarage}>(SimpleCarFactory.garageStoragePath)

        signer.capabilities.publish(garagePublicCapability, at: SimpleCarFactory.garagePublicPath)
    }

    execute {

    }
}