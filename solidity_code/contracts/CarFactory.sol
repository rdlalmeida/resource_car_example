// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract CarFactory {
    // Contract metadata parameters
    uint256 private nextCarId;
    uint256 private nextGarageId;
    address public factoryOwner;

    // Car asset metadata parameters
    mapping(uint256 carId => address) private carOwners; 
    mapping(uint256 carId => string) public carColors;
    mapping(uint256 carId => string) public licencePlates;
    mapping(uint256 carId => bool) public runningCar;
    mapping(uint256 carId => string) private insurancePolicies;
    
    // Garage asset metadata parameters
    mapping(uint256 garageId => address) private garageOwners;
    mapping(uint256 carId => uint256) private garageStore;

    // Events
    event CarCreated(uint256 _carId, address _carOwner, string _licencePlate);
    event CarStarted(uint256 _carId, address _carOwner, string _licencePlate);
    event CarStopped(uint256 _carId, address _carOwner, string _licencePlate);
    event CarDestroyed(uint256 _carId, address _carOwner, string _licencePlate);

    // Contract constructor
    constructor() {
        nextCarId = 1;
        nextGarageId = 1;
        factoryOwner = msg.sender;
    }

    // Create new Car asset
    function createCar(
        address newOwner,
        string memory newCarColor,
        string memory newLicencePlate,
        string memory newInsurancePolicy
        ) public returns(uint256) {
        // Only the contract deployer should be able to run this function
        require(msg.sender == factoryOwner, 
            "You don't own this car factory!");

        // Create a new unique ID "manually"
        uint256 currentCarId = nextCarId++;

        // Set the metadata parameters in the respective mappings
        carOwners[currentCarId] = newOwner;
        carColors[currentCarId] = newCarColor;
        licencePlates[currentCarId] = newLicencePlate;
        runningCar[currentCarId] = false;
        insurancePolicies[currentCarId] = newInsurancePolicy;

        // Emit the event to inform users of a new Car being created
        emit CarCreated(currentCarId, newOwner, newLicencePlate);

        // Return the ID of the new Car asset created
        return currentCarId;
    }

    // Create new Garage asset
    function createGarage(address garageOwner) public returns(uint256) {
        // Like the Car, only the contract deployer is authorised to create new Garages
        require(msg.sender == factoryOwner,
        "You don't own this car factory!");

        // Set the new unique ID
        uint256 currentGarageId = nextGarageId++;

        // Fill out the metadata parameters
        garageOwners[currentGarageId] = garageOwner;

        // And return the ID of the new Garage asset created
        return currentGarageId;
    }

    // Store a Car "inside" a Garage
    function storeCar(uint256 carId, uint256 garageId) public {
        // The owner of the Car and Garage must match. It should not
        // be possible to put your Car in someone else's Garage at will
        require(carOwners[carId] == garageOwners[garageId], 
            "The owner of the car and garage need to be the same!");

        // Set the Car "inside" the Garage
        garageStore[carId] = garageId;
    }

    // Retrieve a Car from a given Garage
    function retrieveCar(uint256 carId, uint256 garageId) public {
        // The owner of the Car and the owner of the Garage must be the same
        require(garageOwners[garageId] == carOwners[carId], 
            "The owner of the car and garage need to be the same!");
        
        // And the Car needs to be inside the Garage as well
        require(garageStore[carId] == garageId, 
            "This car is not stored in this garage!");

        // Remove the Car from "inside" the Garage
        delete garageStore[carId];
    }

    // Set a Car to be in the "Running" state (Car.running = true)
    function startCar(uint256 carId) public {
        // As usual, only the owner of the Car should be able to change its state
        require(carOwners[carId] == msg.sender, "You don't own this car!");

        // Check first if the Car is already Running
        if (!runningCar[carId]) {
            // And do the state change only if it is not, thus saving gas on
            // unnecessary operations
            runningCar[carId] = true;
        }

        // Emit the respective event
        emit CarStarted(carId, carOwners[carId], licencePlates[carId]);
    }

    // Set a Car to be in the "Stopped" state (Car.running = false)
    function stopCar(uint256 carId) public {
        // Check that its the owner of the Car that is attempting to change its state
        require(carOwners[carId] == msg.sender, "You don't own this car!");

        // Check that the Car is not in the desired state already
        if (runningCar[carId]) {
            // Toggle the flag only if required 
            runningCar[carId] = false;
        }

        // And finish by emitting the respective event
        emit CarStopped(carId, carOwners[carId], licencePlates[carId]);
    }

    // Simple "getter" to determine the "Running" state of a give Car
    function isCarRunning(uint256 carId) public view returns(bool) {
        return runningCar[carId];
    }

    // Delete a Car asset from the blockchain state
    function destroyCar(uint256 carId) public {
        // Ensure that only the owner of the Car can destroy it
        require(carOwners[carId] == msg.sender, "You don't own this car!");

        // Save the metadata parameter temporarily just to emit the event later on
        address destroyedCarOwner = carOwners[carId];
        string memory destroyedLicencePlate = licencePlates[carId];

        // "Manually" delete every record belonging to the Car from the contract state
        delete insurancePolicies[carId];
        delete runningCar[carId];
        delete licencePlates[carId];
        delete carColors[carId];
        delete carOwners[carId];

        // And finish by emitting the respective event
        emit CarDestroyed(carId, destroyedCarOwner, destroyedLicencePlate);
    }
}
