import "SimpleCarFactory"

access(all) fun main(garageAddress: Address): [UInt64] {
    let garageAccount: &Account = getAccount(garageAddress)

    let garageRef: &{SimpleCarFactory.PublicGarage} = 
        garageAccount
            .capabilities
                .borrow<&{SimpleCarFactory.PublicGarage}>(SimpleCarFactory.garagePublicPath) ??
                panic(
                    "Unable to get a valid &{SimpleCarFactory.PublicGarage} at "
                    .concat(SimpleCarFactory.garagePublicPath.toString())
                    .concat(" from account ")
                    .concat(garageAddress.toString())
                )
    return garageRef.getCarIds()
}