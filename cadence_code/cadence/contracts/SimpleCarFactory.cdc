access(all) contract SimpleCarFactory {
    access(all) let garageStoragePath: StoragePath
    access(all) let garagePublicPath: PublicPath
    access(all) let garageCapabilityReceiverStoragePath: StoragePath
    access(all) let garageCapabilityReceiverPublicPath: PublicPath

    access(all) let factoryAdminStoragePath: StoragePath
    access(all) let factoryAdminPublicPath: PublicPath

    access(all) entitlement Admin

    access(all) 
    event CarCreated(_carId: UInt64, _carOwner: Address, _licencePlate: String)
    access(all) 
    event CarStarted(_carId: UInt64, _carOwner: Address, _licencePlate: String)
    access(all) 
    event CarStopped(_carId: UInt64, _carOwner: Address, _licencePlate: String)
    access(all) 
    event CarDestroyed(_carId: UInt64, _carOwner: Address, _licencePlate: String)

    access(all) resource Car {
        access(all) let carId: UInt64
        access(all) let color: String
        access(all) let licencePlate: String
        access(all) var running: Bool
        access(account) var insurancePolicy: String

        // Resource constructor
        init(_color: String, _licencePlate: String, _insurancePolicy: String) {
            self.carId = self.uuid
            self.color = _color
            self.licencePlate = _licencePlate
            self.running = false
            self.insurancePolicy = _insurancePolicy
        }

        // startCar() protected with access(account)
        access(account) 
        fun starCar(): Void {
            if (!self.running) {
                self.running = true
            }

            emit CarStarted(
                _carId: self.carId, 
                _carOwner: self.owner!.address, 
                _licencePlate: self.licencePlate
                )
        }

        access(account) 
        fun stopCar(): Void {
            if (self.running) {
                self.running = false
            }

            emit CarStopped(
                _carId: self.carId, 
                _carOwner: self.owner!.address, 
                _licencePlate: self.licencePlate
                )
        }

        // Getter for the Car.running state
        access(all) fun isCarRunning(): Bool {
            return self.running
        }
    }

    access(all) resource interface PublicGarage {
        access(all) fun storeCar(carToStore: @SimpleCarFactory.Car): Void
        access(all) fun getCarIds(): [UInt64]
        access(all) fun testPublicCapability(): String
    }

    access(all) resource interface GarageCapabilityReceiverPublic {
        access(all) fun addGarageCapability
            (cap: Capability<&SimpleCarFactory.Garage>)
    }

    access(all) resource GarageCapabilityReceiver: 
        GarageCapabilityReceiverPublic {
    
    access(all) var garageCapability: Capability<&SimpleCarFactory.Garage>?

        init() {
            self.garageCapability = nil
        }

        access(all) fun addGarageCapability
            (cap: Capability<&SimpleCarFactory.Garage>) {
                self.garageCapability = cap
        }
    }

    access(all) fun createGarageCapabilityReceiver(): 
        @SimpleCarFactory.GarageCapabilityReceiver {
        return <- create SimpleCarFactory.GarageCapabilityReceiver()
    }

    // Collection-type resource. Starts as a normal resource
    access(all) resource Garage: PublicGarage {
        // But with an internal capacity to store other resources
        // using a key-value dictionary using the Car's ID as key
        access(all) var storedCars: @{UInt64: SimpleCarFactory.Car}
        
        // Resource constructor. Sets the internal dictionary to an empty one
        init () {
            self.storedCars <- {}
        }

        access(all) fun getCarIds(): [UInt64] {
            return self.storedCars.keys
        }

        access(all) fun testPublicCapability(): String {
            return "I have a public &{SimpleCarFactory.PublicGarage}"
        }

        access(all) fun testPrivateCapability(): String {
            return "Got a private capability from the CapabilityReceiver"
        } 

        // Store a Car provided as input into this Garage
        access(all) fun storeCar(carToStore: @SimpleCarFactory.Car): Void {
            /* 
                Type Safety: always move whatever may be stored in a storage
                position to a variable followed by moving the desired resource
                into the same position
            */
            let garageSlot: @AnyResource? 
                <- self.storedCars[carToStore.carId] <- carToStore

            // And destroy the variable afterwards to maintain linear consistency
            destroy garageSlot
        }

        // Retrieve a Car from this Garage
        access(all) fun getCar(carId: UInt64): @SimpleCarFactory.Car {
            /* 
                Attempt to retrieve a Car with the provided ID from this 
                Garage's internal storage. If the Car does not exist, a 
                nil is returned instead. But I've set the storedCar variable
                to be of type '@SimpleCarFactory.Car', so it cannot be cast
                into a nil due to Cadence's type strictness. Trying to do so
                will trigger the panic statement, which reverts the transaction 
                invoking this function with the message in the statement's argument
            */
            let storedCar: @SimpleCarFactory.Car <- 
                self.storedCars.remove(key: carId) ??
                panic(
                    "Car with id "
                    .concat(carId.toString())
                    .concat(" is not in this Garage!")
                    )
            // If I got here, I have a valid Car to return
            return <- storedCar
        }

        /*
            Destroy a Car. I don't need to validate the caller of this 
            function because it is implemented in the Garage resource 
            description. This means than to call this function, one needs to own
            a Garage in the first place. To prevent this function to be called 
            through a public reference, it was protected with an 'Admin'
            entitlement, which means that only an authorised reference
            can access it and only the owner of the resource can get those.
        */
        access(all) fun destroyCar(oldCarId: UInt64): Void {
            // Grab the car to be destroyed from the garage collection, 
            // if it exists. Panic if not
            let carToDestroy: @SimpleCarFactory.Car 
                <- self.storedCars.remove(key: oldCarId) ??
                panic(
                    "The garage from account "
                    .concat(self.owner!.address.toString())
                    .concat(" does not have any cars with ID ")
                    .concat(oldCarId.toString())
                )

            // The car to be destroyed exists in this garage and it was 
            // remove from the internal storage dictionary
            let oldCarOwner: Address = self.owner!.address
            let oldLicencePlate: String = carToDestroy.licencePlate

            // Destroy the car
            destroy carToDestroy

            // Finish with the proper event emit
            emit CarDestroyed(
                _carId: oldCarId, 
                _carOwner: oldCarOwner, 
                _licencePlate: oldLicencePlate
                )
        }
    }

    // Anyone can create a new Garage, since it's not that critical
    access(all) fun createGarage(): @{SimpleCarFactory.PublicGarage} {
        return <- create SimpleCarFactory.Garage()
    }

    access(all) resource FactoryAdmin {
        /*    
            The creation of new Cars is protected with the Admin entitlement.
            Therefore only authorised references
            can create new Cars and those are only obtainable by the owner of
            this FactoryAdmin.
        */
        access(Admin) fun createCar(
            newLicencePlate: String,
            newColor: String,
            newInsurancePolicy: String,
            newCarOwner: Address
            ) {
                // Create the car only if the owner provided has a valid Garage
                // already set in his/her account to store the new Car
                // Check if the owner account is properly set
                let ownerAccount: &Account = getAccount(newCarOwner);
                let ownerGarageRef: &{SimpleCarFactory.PublicGarage} = 
                    ownerAccount.capabilities.borrow<&{SimpleCarFactory.PublicGarage}>
                    (SimpleCarFactory.garagePublicPath) ??
                        panic(
                            "Unable to retrieve a valid &Garage for account "
                            .concat(newCarOwner.toString())
                            .concat(". Cannot continue!")
                        )

                // The newCarOwner has a valid Garage to store 
                // the new car into. Create the Car

                let newCar: @SimpleCarFactory.Car 
                    <- create SimpleCarFactory.Car(
                        _color: newColor,
                        _licencePlate: newLicencePlate,
                        _insurancePolicy: newInsurancePolicy
                    )

                // Emit the CarCreated event
                emit CarCreated(
                    _carId: newCar.carId, 
                    _carOwner: newCarOwner, 
                    _licencePlate: newLicencePlate
                    )

                // Store the in the newCarOwner's Garage
                ownerGarageRef.storeCar(carToStore: <- newCar)
            }
    }

    // Contract constructor
    init() {
        // Set default paths to be able to access them trough 
        // a contract abstraction
        self.garageStoragePath = /storage/Garage
        self.garagePublicPath = /public/Garage
        self.garageCapabilityReceiverStoragePath = /storage/GarageCapabilityReceiver
        self.garageCapabilityReceiverPublicPath = /public/GarageCapabilityReceiver
        self.factoryAdminStoragePath = /storage/FactoryAdmin
        self.factoryAdminPublicPath = /public/FactoryAdmin

        // Cycle any old FactoryAdmin resources still in storage. 
        // This is useful during contract debugging
        // to avoid having to "clean up" storage between deployments
        let oldFactoryAdmin: @AnyResource? 
            <- self.account.storage.load<@AnyResource?>(
                from: self.factoryAdminStoragePath)
        
        // Destroy the old version just in case there was an update to its code
        // since the last deployment
        destroy oldFactoryAdmin

        // Recreate the FactoryAdmin resource from this contract's
        //  code version to have it updated
        let newFactoryAdmin: @SimpleCarFactory.FactoryAdmin 
        <- create SimpleCarFactory.FactoryAdmin()

        // Save it to the same path as the old one
        self.account.storage.save(<- newFactoryAdmin, 
            to: SimpleCarFactory.factoryAdminStoragePath)

        // Create, store and publish a public (normal) capability
        // to a Garage resource belonging to this contract deployer
        let newGarage: @SimpleCarFactory.Garage <- create SimpleCarFactory.Garage()

        let randomResource: @AnyResource <- 
            self.account
                .storage
                    .load<@SimpleCarFactory.Garage>
                        (from: SimpleCarFactory.garageStoragePath)
        destroy randomResource

        self.account.storage.save(<- newGarage, to: SimpleCarFactory.garageStoragePath)

        // Create and publish a "normal" capability
        let garagePublicCap: Capability<&{SimpleCarFactory.PublicGarage}> = 
            self.account
                .capabilities
                    .storage
                        .issue<&{SimpleCarFactory.PublicGarage}>
                            (SimpleCarFactory.garageStoragePath)
        self.account.capabilities.publish(garagePublicCap, 
            at: SimpleCarFactory.garagePublicPath)
    }
}