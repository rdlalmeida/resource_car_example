import "Burner"
import "FungibleToken"
import "FlowToken"

access(all) contract CarFactory {
    access(all) event CarCreated(carId: UInt64)
    access(all) event CarStarted(carId: UInt64)
    access(all) event CarStopped(carId: UInt64)
    access(all) event CarSold(carId: UInt64, newOwner: Address)
    access(all) event CarDestroyed(carId: UInt64)

    access(all) event GarageCreated(owner: Address)
    access(all) event GarageDestroyed(owner: Address)
    access(all) event GarageSlotOccupied(resourceType: Type)
    access(all) event GarageMissingCar(carId: UInt64)

    access(all) event FactoryAdminCreated(owner: Address)
    access(all) event FactoryAdminDestroyed(owner: Address)

    // Set of contract-stored storage and public path for easier access
    access(all) let garageStoragePath: StoragePath
    access(all) let garagePublicPath: PublicPath
    access(all) let factoryAdminStoragePath: StoragePath
    access(all) let accountVaultPublicPath: PublicPath

    // Custom entitlement
    access(all) entitlement Admin

    access(all) resource Car: Burner.Burnable {
        access(all) let carId: UInt64
        access(all) let licence: String
        access(all) let buildDate: String
        access(all) let passengerCapacity: UInt8
        access(all) var color: String
        access(all) var running: Bool
        access(all) let power: UInt64
        access(all) let fuelType: UInt8
        access(account) var odometer: UInt64
        access(account) var price: UFix64
        access(account) var insurancePolicy: String

        access(account) fun startCar(): Void {
            if (!self.running) {
                self.running = true
            }
        }

        access(account) fun stopCar(): Void {
            if (self.running) {
                self.running = false
            }
        }

        // Callback function to be automatically executed when a Car resource is burned using the Burner contract
        access(contract) fun burnCallback() {
            emit CarDestroyed(carId: self.carId)
        }

        // Resource constructor, to be run every time a new Car resource is created
        init(
            _licence: String, 
            _buildDate: String, 
            _passengerCapacity: UInt8,
            _color: String,
            _power: UInt64,
            _fuelType: UInt8,
            _price: UFix64,
            _insurancePolicy: String
            ) {
                self.carId = self.uuid
                self.licence = _licence
                self.buildDate = _buildDate
                self.passengerCapacity = _passengerCapacity
                self.color = _color
                // New cars are created stopped
                self.running = false
                self.power = _power
                self.fuelType = _fuelType
                // New cars have not been driven yet
                self.odometer = 0
                self.price = _price
                self.insurancePolicy = _insurancePolicy
        }
    }

    // Collection-type resource to allow easy storage and loading of multiple CarFactory.Car resources in a single account
    access(all) resource Garage: Burner.Burnable {
        // Dictionary to store Cars into
        access(account) var storedCars: @{UInt64: CarFactory.Car}
        access(self) let garageOwner: Address

        access(all) fun storeCar(carToStore: @CarFactory.Car): Void {
            let garageSlot: @AnyResource? <- self.storedCars[carToStore.carId] <- carToStore

            // Cars are unique and Garages can only store CarFactory.Car resources. This means that it is impossible to
            // have multiple Cars in this contract with the same carId. Yet, Cadence type safety rules "force" me to
            // deal with the possibility of something else being stored currently in the storage slot pointed by the 
            // carToStore.carId index.
            if (garageSlot != nil) {
                // Emit an event signaling that something else was stored in the internal dictionary, under the carId index.
                emit GarageSlotOccupied(resourceType: garageSlot.getType())
            }

            // And destroy whatever was retrieved from that slot. If all works as expected, (garageSlot == nil) 
            // in 100% of the cases, so this is a bit of a pointless instruction.
            destroy garageSlot
        }

        // This function returns an optional, which is means that the function can return either a Car, if one exists in the 
        // carId index position in the self.storedCars dictionary, or nil, if nothing exists yet at that index. The retrieval
        // command does not check for that, so whoever receives the output of this function must test if they received a
        // valid Car or a nil.
        access(account) fun retrieveCar(carId: UInt64): @CarFactory.Car? {
            let storedCar: @CarFactory.Car? <- self.storedCars.remove(key: carId)

            if (storedCar == nil) {
                emit GarageMissingCar(carId: carId)
            }
            // The '<-' operator is used to move a resource. In this case, the resource is withdrawn from the internal storage
            // dictionary and it is unhoused at this point. At the end of this function, the resource needs to go somewhere.
            // In this specific case, because this function returns a resource (the '@' in the return type means resource)
            // the '<-' operator is used to move the resource from within the function context into whatever context (another 
            // function or a transaction) invoked this function in the first place.
            return <- storedCar
        }

        // The sell function is the most complex
        access(account) fun sellCar(carIdToSell: UInt64, newOwner: Address, pricePaid: @FlowToken.Vault): Void {
            // First, retrieve the car to be sold from the Garage. Panic if no car was found since it is pointless
            // to carry on with this without one. Panic stops the current transaction and reverts the global state
            // to the point it was before this instruction.
            // After this instruction, the Car resource is no longer inside the Garage. So, currently, the resource
            // is in an unstable state. By the end of this function, this resource needs to end up in a permanent location
            // of any kind, or destroyed. This contract cannot be deployed until all the type safety restrictions from Cadence are met
            let carToSell: @CarFactory.Car <- self.storedCars.remove(key: carIdToSell) ??
            panic(
                "Unable to retrieve car with Id "
                .concat(carIdToSell.toString())
                .concat(" from a Garage in account ")
                .concat(newOwner.toString())
                )

            // Check that the funds provided are enough to cover the cost of the car. Panic if they aren't
            // because it is impossible to continue the sale without sufficient funds
            if (pricePaid.balance < carToSell.price) {
                panic(
                    "Not enough funds provided to buy Car #"
                    .concat(carToSell.uuid.toString())
                    .concat(". Car costs ")
                    .concat(carToSell.price.toString())
                    .concat(" FLOW but buyer only has provided ")
                    .concat(pricePaid.balance.toString())
                    .concat(" FLOW to buy it.")
                )
            }

            // It is possible that the funds provided exceed the price of the car. If that is the case, compute another Vault to
            // hold the change to return to the buyer. After withdrawing the price of the car from the initial funds provided,
            // whatever was left in the pricePaid vault is now the change to return to the buyer, if any (the Vault can have 0 FLOW left)
            let carPrice: @FlowToken.Vault <- pricePaid.withdraw(amount: carToSell.price) as! @FlowToken.Vault 

            // Grab a reference to the account of the buyer
            let buyerAccount: &Account = getAccount(newOwner)

            // And from the account reference, borrow another reference but for the public interface of the buyer's Garage resource. I need to
            // access it to deposit the bought car. Deposit functions are "access(all)" so they can be invoked from references such as this one.
            // Panic if the buyer does not have a Garage yet since I need one to complete the sale.
            let buyerGarageRef: &CarFactory.Garage = buyerAccount.capabilities.borrow<&CarFactory.Garage>(CarFactory.garagePublicPath) ??
            panic(
                "Unable to retrieve a valid &CarFactory.Garage for account "
                .concat(newOwner.toString())
                )

            // Grab a reference to the buyer's FLOW Vault to deposit any leftover change into it after the sale
            let buyerVaultRef: &FlowToken.Vault = buyerAccount.capabilities.borrow<&FlowToken.Vault>(CarFactory.accountVaultPublicPath) ??
            panic(
                "Unable to retrieve a valid &FlowToken.Vault from account "
                .concat(newOwner.toString())
            )

            // I need a reference to the seller account as well
            let sellerAccount: &Account = getAccount(self.owner!.address)

            // Because I need to access its main FLOW Vault to deposit the funds paid to get the Car into it
            let sellerVaultRef: &FlowToken.Vault = sellerAccount.capabilities.borrow<&FlowToken.Vault>(CarFactory.accountVaultPublicPath) ??
            panic(
                "Unable to retrieve a valid &FlowToken.Vault from account "
                .concat(self.owner!.address.toString())
            )

            // All the necessary elements to complete the sale are ready. Proceed
            // First, deposit the full price of the car into the seller's account
            sellerVaultRef.deposit(from: <- carPrice)
            // Second, with the car properly paid, store the car now into the buyer's account
            buyerGarageRef.storeCar(carToStore: <- carToSell)
            // Finish the process by returning any change still left in the pricePaid FLOW Vault back into the buyer's account
            buyerVaultRef.deposit(from: <- pricePaid)
        }

        access(Admin) fun destroyCar(oldCarId: UInt64): Void {
            let carToDestroy: @CarFactory.Car? <- self.storedCars.remove(key: oldCarId)

            if (carToDestroy == nil) {
                emit GarageMissingCar(carId: oldCarId)
            }
            Burner.burn(<- carToDestroy)
        }

        access(contract) fun burnCallback() {
            emit GarageDestroyed(owner: self.garageOwner)
        }

        // Garage constructor. New Garages are create with an empty storage dictionary, as expected
        init(_garageOwner: Address) {
            self.storedCars <- {}
            self.garageOwner = _garageOwner
        }
    }

    // A Factory Admin resource to regulate the production of new Cars
    access(all) resource FactoryAdmin: Burner.Burnable {
        access(self) let factoryAdminOwner: Address

        // Only the Factory Administrator can create new Cars. New resources need to have their creation
        // properly protected or otherwise anyone can create new resources, which is always a problem.
        access(Admin) fun createCar(
            newLicence: String,
            newBuildDate: String,
            newPassengerCapacity: UInt8,
            newColor: String,
            newPower: UInt64,
            newFuelType: UInt8,
            newPrice: UFix64,
            newInsurancePolicy: String
        ): @CarFactory.Car {
            let newCar: @CarFactory.Car <- create CarFactory.Car(
                _licence: newLicence,
                _buildDate: newBuildDate,
                _passengerCapacity: newPassengerCapacity,
                _color: newColor,
                _power: newPower,
                _fuelType: newFuelType,
                _price: newPrice,
                _insurancePolicy: newInsurancePolicy
            )
            emit CarCreated(carId: newCar.carId)
            return <- newCar
        }

        access(all) fun destroyCar(oldCar: @CarFactory.Car): Void {
            Burner.burn(<- oldCar)
        }

        access(contract) fun burnCallback() {
            emit FactoryAdminDestroyed(owner: self.factoryAdminOwner)
        }

        init(_factoryOwner: Address) {
            self.factoryAdminOwner = _factoryOwner
        }
    }

    init() {
        // Storage and Public paths set as variables at the contract level so that anyone can access them by running
        // CarFactory.<variable_name>
        self.garageStoragePath = /storage/CarGarage
        self.garagePublicPath = /public/CarGarage
        self.factoryAdminStoragePath = /storage/FactoryAdmin
        self.accountVaultPublicPath = /public/flowTokenBalance

        // Only one Factory Administrator exist at all times and this is defined by the contract constructor since this function
        // runs only one per contract deployed.
        // First, any old FactoryAdmin resources that may be stored in the account (from older contract deployments) are retrieved since
        // the storage path can only store one at a time. This is a somewhat standard behavior in Cadence
        let oldFactoryAdmin: @AnyResource? <- self.account.storage.load<@AnyResource?>(from: self.factoryAdminStoragePath)
        
        // Destroy the old FactoryAdmin, if any was there in the first place. It no longer serves any use
        Burner.burn(<- oldFactoryAdmin)

        // Create a brand new Factory Admin resource and save it in the same storage path as the old one
        let newFactoryAdmin: @CarFactory.FactoryAdmin <- create CarFactory.FactoryAdmin(_factoryOwner: self.account.address)
        self.account.storage.save(<- newFactoryAdmin, to: self.factoryAdminStoragePath)
        emit FactoryAdminCreated(owner: self.account.address)
    }
}