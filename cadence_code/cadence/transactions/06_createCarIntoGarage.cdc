import "SimpleCarFactory"

transaction(
    recipientAddress: Address, 
    licencePlate: String, 
    color: String, 
    insurancePolicy: String
    ) {
    let factoryAdminRef: auth(SimpleCarFactory.Admin) &SimpleCarFactory.FactoryAdmin
    let recipientAddress: Address

    prepare(signer: auth(SimpleCarFactory.Admin, Storage) &Account) {
        self.recipientAddress = recipientAddress

        self.factoryAdminRef = signer
            .storage
                .borrow<auth(SimpleCarFactory.Admin) &SimpleCarFactory.FactoryAdmin>
                (from: SimpleCarFactory.factoryAdminStoragePath) ??
        panic(
            "Unable to retrieve a valid auth(SimpleCarFactory.Admin) &SimpleCarFactory.FactoryAdmin at "
            .concat(SimpleCarFactory.factoryAdminStoragePath.toString())
            .concat(" from account ")
            .concat(signer.address.toString())
        )

        self.factoryAdminRef.createCar(
            newLicencePlate: licencePlate,
            newColor: color,
            newInsurancePolicy: insurancePolicy,
            newCarOwner: recipientAddress
        )
    }

    execute {
    }
}