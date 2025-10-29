import "SimpleCarFactory"

transaction() {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        let oldGarage: @{SimpleCarFactory.PublicGarage}? <- signer.storage.load<@{SimpleCarFactory.PublicGarage}>(from: SimpleCarFactory.garageStoragePath)

        log(
            "Retrieved a "
            .concat(oldGarage.getType().identifier)
            .concat("-type resource at ")
            .concat(SimpleCarFactory.garageStoragePath.toString())
            .concat(" from account ")
            .concat(signer.address.toString())
        )

        destroy oldGarage

        log(
            "Destroyed it!"
        )
    }

    execute{

    }
}