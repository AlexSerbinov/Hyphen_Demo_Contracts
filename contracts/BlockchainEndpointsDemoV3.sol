//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/// @title Demo Contract for DON (Decentralized Oracle Network) Participants: BlockchainEndpointsDemoV3
/// @notice This contract serves as a demonstration tool to show how endpoints operate in an EVM (Ethereum Virtual Machine) environment.
/// @dev This demo contract integrates with Chainlink for off-chain data requests and showcases various environmental data retrieval methods.
/// Due to its demo nature, it contains many gas-inefficient aspects, such as the use of strings for numerous variables (refer to detailed comments below).
/// Additionally, it employs certain tricks to enhance data presentation in block explorers. For instance, variables with the '_last' prefix are designed
/// to display data conveniently in block explorers, as these platforms often do not show keys of struct type variables.

contract BlockchainEndpointsDemoV3 is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    /// @notice Stores different job IDs for Chainlink requests.
    /// @dev jobId1, jobId2, jobId3 are used to track different types of jobs submitted to Chainlink.
    /// jobIds array aggregates these for easier management.
    bytes32 private jobId1;
    bytes32 private jobId2;
    bytes32 private jobId3;
    bytes32[] jobIds = [jobId1, jobId2, jobId3];

    /// @notice Fee to be paid for Chainlink requests.
    /// @dev The fee is set based on the LINK token's divisibility.
    uint256 private fee;

    /// @notice Address of the contract owner.
    /// @dev Used for administrative and ownership control.
    address public contractOwner;

    /// @notice Variables to store the latest request details for demonstration purposes.
    /// @dev These variables with the '_last' prefix are used to conveniently display data in a block explorer.
    /// Since block explorers often do not show the keys of struct type variables, these individual variables
    /// provide a clear view of the latest request's data for demo purposes. They represent the hash, status,
    /// method name, a calculated parameter, timestamp, and values of various gases (CH4, CO2, NO2, CO) from
    /// the last processed request.
    bytes32 private _lastRequestHash;
    string private _lastRequestStatus;
    string private _lastMethodName;
    int256 private _lastMultipliedParametr;
    uint256 private _lastTimestamp;
    int256 private _lastCh4Value;
    int256 private _lastCo2Value;
    int256 private _lastNo2Value;
    int256 private _lastCoValue;

    /// @notice Whitelist of addresses allowed to interact with certain functions.
    /// @dev Mapping from address to boolean to manage access control.
    mapping(address => bool) public whitelist;

    /// @notice Stores hashes of sent requests.
    /// @dev Mapping from uint256 to bytes to track request hashes.
    mapping(uint256 => bytes) public sentHashes;

    /// @notice The number of confirmations required from Chainlink nodes.
    /// @dev Set to 2 by default, can be changed by the contract owner.
    uint256 public requiredNodeConfirmations = 2;

    uint256 private counter;
    uint256 lastUpdateTime;

    /// @notice Last hash sent for a data request.
    /// @dev Used for tracking the latest request hash.
    bytes32 public lastSentHash;

    /// @notice Data structure for storing responses from Gas Data Nodes.
    /// @dev Aggregates multiple values related to environmental data.
    struct GasDataNode {
        uint256 count;
        int256 ch4Value;
        int256 co2Value;
        int256 no2Value;
        int256 coValue;
    }

    /// @notice Data structure for final gas data.
    /// @dev Similar to GasDataNode, but includes request hash and status.
    struct FinalGasData {
        bytes32 requestHash;
        string requestStatus;
        string methodName;
        int256 multiplied;
        uint256 timestamp;
        int256 ch4Value;
        int256 co2Value;
        int256 no2Value;
        int256 coValue;
    }

    mapping(bytes32 => GasDataNode) private gasDataNodes;
    mapping(bytes32 => FinalGasData) public getResultBySentHash;

    /// @notice Emits when multiple parameters are fulfilled.
    /// @dev Triggers an event with detailed environmental data.
    event MultipleParametrsFulfilled(
        bytes32 indexed requestId,
        bytes requestHash,
        string requestStatus,
        string methodName,
        int256 multiplied,
        uint256 timestamp,
        int256 co2,
        int256 co,
        int256 ch4,
        int256 no2
    );

    /// @notice Constructor initializes the contract with Chainlink settings.
    /// @dev Sets up the contract owner, Chainlink token, oracle, job IDs, and fee.
    constructor() ConfirmedOwner(msg.sender) {
        contractOwner = msg.sender;
        whitelist[msg.sender] = true;
        setChainlinkToken(0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846); // 846 testnet
        setChainlinkOracle(0x9EFC601923b1092CBED679FC31f609583d893322); //  322 testnet
        jobId1 = "a085ce11aeb74996b8a945ece2ffa631";
        jobId2 = "a085ce11aeb74996b8a945ece2ffa632";
        jobId3 = "a085ce11aeb74996b8a945ece2ffa633";
        fee = (1 * LINK_DIVISIBILITY) / 100000;
    }

    /// @notice Data structure to manage request data.
    /// @dev Holds parameters and method names for requests.
    struct RequestData {
        string parameters;
        string methodName;
        bytes requestHashBytes;
    }

    /*
    Why We Use String Types for Variables:

    I'm understand of the importance of optimizing gas usage in blockchain and understand that using strings
    for things like 'year' is not efficient. However, we had a specific reason for doing it in our project. 
    Our Chainlink infrastructure has three main parts:
        - a smart contract
        - a TOML job
        - and a backend adapter
    The data flows from the smart contract to the TOML job and then to the adapter. We aimed to make a 
    UNIVERSAL TOML job that didn't need frequent updates. The Chainlink TOML job is pretty restricted in
    how it handles data, unlike JavaScript or even Solidity (https://docs.chain.link/chainlink-nodes/oracle-jobs/jobs). 
    Our project's goal was to enable many independent users to operate their own Decentralized Oracle Network (DON) 
    with their own TOML jobs without needing frequent updates from everyone. Since our project was still evolving, 
    we had to frequently change how our system's endpoints worked. The easiest way to do this during development 
    was by using string types in our smart contracts. We knew a more efficient way without strings for the final product,
    but that would require every participant to update their TOML job for each major update in the system.
    */

    /// @notice Retrieves anthropogenic (human-caused) emission values by sector.
    /// @dev Constructs a request with specified parameters for anthropogenic emissions and sends it to Chainlink.
    /// This function uses string types for all input parameters to ensure compatibility with various data formats.
    /// @param _year Year of the data (format: "YYYY", e.g., "2005").
    /// @param _month Month of the data (format: "M", e.g., "1").
    /// @param _sectorName Name of the sector (example: "sum").
    /// @param _gas Type of gas (example: "CO2").
    /// @param _latitude Latitude for location-based data (format: decimal, example: "-77.85").
    /// @param _longitude Longitude for location-based data (format: decimal, example: "166.35").
    /// @return bytes memory representing request hash.
    function getEmissionAnthroValuesBySector(
        string memory _year,
        string memory _month,
        string memory _sectorName,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&year=",
                _year,
                "&month=",
                _month,
                "&sectorName=",
                _sectorName,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );

        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getEmissionAnthroValuesBySectorBC"
        });

        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves aviation emission values by specific level.
    /// @dev Sends a request for aviation emission data for a specific level to Chainlink.
    /// Uses string types for parameters to maintain a flexible and universal data request format.
    /// @param _year Year for which data is requested (format: "YYYY", e.g., "2000").
    /// @param _month Month for which data is requested (format: "M", e.g., "3").
    /// @param _gas Type of gas for which data is requested (example: "CO2").
    /// @param _levelValue Level value for which data is requested (format: decimal, example: "4.575").
    /// @param _latitude Latitude coordinate for location-specific data (format: decimal, example: "-55.75").
    /// @param _longitude Longitude coordinate for location-specific data (format: decimal, example: "-67.75").
    /// @return bytes A unique request hash as a byte array.
    function getEmissionAviaValuesByLevel(
        string memory _year,
        string memory _month,
        string memory _gas,
        string memory _levelValue,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&year=",
                _year,
                "&month=",
                _month,
                "&levelValue=",
                _levelValue,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );

        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getEmissionAviaValuesByLevelBC"
        });

        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves biological emission values by month.
    /// @dev Constructs and sends a request to Chainlink for biological emission data for a specific month.
    /// String types are used for all parameters for uniformity and flexibility in data requests.
    /// @param _year Year for which data is requested (format: "YYYY", e.g., "2000").
    /// @param _month Month for which data is requested (format: "M", e.g., "1").
    /// @param _gas Type of gas for which data is requested (example: "CH4").
    /// @param _hour Hour for which data is requested (format: "H", e.g., "0").
    /// @param _latitude Latitude coordinate for location-specific data (format: decimal, example: "-56.5").
    /// @param _longitude Longitude coordinate for location-specific data (format: decimal, example: "-68.75").
    /// @return bytes A unique request hash as a byte array.
    function getEmissionBioValuesByMonth(
        string memory _year,
        string memory _month,
        string memory _gas,
        string memory _hour,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&year=",
                _year,
                "&month=",
                _month,
                "&hour=",
                _hour,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getEmissionBioValuesByMonthBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves daily emission values from ships.
    /// @dev Sends a request for ship emission data for a specific day to Chainlink.
    /// Uses string types for parameters to allow flexibility in Chainlink integration.
    /// @param _year Year of the data (format: "YYYY").
    /// @param _month Month of the data (format: "M").
    /// @param _day Day of the data (format: "D").
    /// @param _gas Type of gas (example: "CO2").
    /// @param _latitude Latitude coordinate (format: decimal, example: "82.25").
    /// @param _longitude Longitude coordinate (format: decimal, example: "-114").
    /// @return bytes The request hash in bytes format.
    function getEmissionShipValuesByDay(
        string memory _year,
        string memory _month,
        string memory _day,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&year=",
                _year,
                "&month=",
                _month,
                "&day=",
                _day,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getEmissionShipValuesByDayBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves monthly emission values for a specific term.
    /// @dev Sends a request for term emission data for a specific month to Chainlink.
    /// Uses string types for parameters for consistent Chainlink job formatting.
    /// @param _year Year of the data (format: "YYYY").
    /// @param _month Month of the data (format: "M").
    /// @param _gas Type of gas (example: "CH4").
    /// @param _latitude Latitude coordinate (format: decimal, example: "52.25").
    /// @param _longitude Longitude coordinate (format: decimal, example: "-110.75").
    /// @return bytes The request hash in bytes format.
    function getEmissionTermValuesByMonth(
        string memory _year,
        string memory _month,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&year=",
                _year,
                "&month=",
                _month,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getEmissionTermValuesByMonthBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves monthly soil emission values.
    /// @dev Sends a request for soil emission data to Chainlink.
    /// Uses string types for parameters for adaptability in data requests.
    /// @param _year Year of the data (format: "YYYY").
    /// @param _month Month of the data (format: "M").
    /// @param _sector Sector of emission (example: "total").
    /// @param _gas Type of gas (example: "NO").
    /// @param _latitude Latitude coordinate (format: decimal, example: "-59.25").
    /// @param _longitude Longitude coordinate (format: decimal, example: "-26.75").
    /// @return bytes The request hash in bytes format.
    function getEmissionSoilValuesByMonth(
        string memory _year,
        string memory _month,
        string memory _sector,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) internal returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&year=",
                _year,
                "&month=",
                _month,
                "&sector=",
                _sector,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getEmissionSoilValuesByMonthBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves greenhouse gas values by level.
    /// @dev Sends a request for greenhouse gas data at a specific level to Chainlink.
    /// Uses string types for parameters for universal applicability.
    /// @param _date Date of the data (format: "YYYY-MM-DD").
    /// @param _level Level of measurement (example: "Pressure").
    /// @param _levelValue Level value (format: decimal, example: "7").
    /// @param _gas Type of gas (example: "CO2").
    /// @param _latitude Latitude coordinate (format: decimal, example: "90").
    /// @param _longitude Longitude coordinate (format: decimal, example: "0").
    /// @return bytes The request hash in bytes format.
    function getGreenHouseValuesByLevel(
        string memory _date,
        string memory _level,
        string memory _levelValue,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&date=",
                _date,
                "&level=",
                _level,
                "&levelValue=",
                _levelValue,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getGreenHouseValuesByLevelBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves monthly greenhouse gas values.
    /// @dev Constructs and sends a request to Chainlink for greenhouse gas data for a specified month.
    /// Uses string types for all parameters for flexible integration with Chainlink nodes.
    /// @param _year Year of the data (format: "YYYY", e.g., "2003").
    /// @param _month Month of the data (format: "M", e.g., "5").
    /// @param _gas Type of gas (e.g., "CO2").
    /// @param _LevelValue Level value (decimal format, e.g., "7").
    /// @param _latitude Latitude coordinate (decimal format, e.g., "90").
    /// @param _longitude Longitude coordinate (decimal format, e.g., "0").
    /// @return bytes Request hash as a byte array.
    function getGreenHouseMonthlyValuesByMonth(
        string memory _year,
        string memory _month,
        string memory _gas,
        string memory _LevelValue,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&year=",
                _year,
                "&month=",
                _month,
                "&gas=",
                _gas,
                "&LevelValue=",
                _LevelValue,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getGreenHouseMonthlyValuesByMonthBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves reanalysis values by level for a specific date.
    /// @dev Sends a request for reanalysis data by level for a given date to Chainlink.
    /// String types are used for parameters to allow update-independent Chainlink job compatibility.
    /// @param _date Date of the data (format: "YYYY-MM-DD", e.g., "2003-02-01").
    /// @param _level Measurement level (e.g., "Pressure").
    /// @param _levelValue Level value (decimal format, e.g., "5").
    /// @param _gas Type of gas (e.g., "CO").
    /// @param _latitude Latitude coordinate (decimal format, e.g., "90").
    /// @param _longitude Longitude coordinate (decimal format, e.g., "1.5").
    /// @return bytes Request hash as a byte array.
    function getReanalysisValuesByLevel(
        string memory _date,
        string memory _level,
        string memory _levelValue,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&date=",
                _date,
                "&level=",
                _level,
                "&levelValue=",
                _levelValue,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getReanalysisValuesByLevelBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves monthly reanalysis values for a specific level and month.
    /// @dev Constructs and sends a Chainlink request for reanalysis data for a specific month and level.
    /// Utilizes string types for parameters for consistency in data request format.
    /// @param _year Year of the data (format: "YYYY", e.g., "2003").
    /// @param _month Month of the data (format: "M", e.g., "2").
    /// @param _level Measurement level (e.g., "Model").
    /// @param _levelValue Level value (decimal format, e.g., "60").
    /// @param _gas Type of gas (e.g., "CO").
    /// @param _latitude Latitude coordinate (decimal format, e.g., "90").
    /// @param _longitude Longitude coordinate (decimal format, e.g., "1.5").
    /// @return bytes Request hash as a byte array.
    function getReanalysisMonthlyValuesByMonth(
        string memory _year,
        string memory _month,
        string memory _level,
        string memory _levelValue,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&year=",
                _year,
                "&month=",
                _month,
                "&level=",
                _level,
                "&levelValue=",
                _levelValue,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getReanalysisMonthlyValuesByMonthBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves air reanalysis values by hour for a specific date.
    /// @dev Sends a request to Chainlink for hourly air reanalysis data for a given date.
    /// Uses string types for parameters for universal TOML job compatibility.
    /// @param _date Date of the data (format: "YYYY-MM-DD", e.g., "2016-02-01").
    /// @param _hour Hour of the day (format: "H", e.g., "0").
    /// @param _gas Type of gas (e.g., "CO").
    /// @param _latitude Latitude coordinate (decimal format, e.g., "30").
    /// @param _longitude Longitude coordinate (decimal format, e.g., "-25").
    /// @return bytes Request hash as a byte array.
    function getAirReanalysesValuesByHour(
        string memory _date,
        string memory _hour,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&date=",
                _date,
                "&hour=",
                _hour,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getAirReanalysesValuesByHourBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves greenhouse gas inversion data for a specific month.
    /// @dev Constructs and sends a request to Chainlink for greenhouse gas inversion data for a given month.
    /// String types are used for parameters for flexible and update-independent data requests.
    /// @param _date Date of the data (format: "YYYY-MM-DD", e.g., "2018-02-08").
    /// @param _gas Type of gas (e.g., "CH4").
    /// @param _latitude Latitude coordinate (decimal format, e.g., "-89").
    /// @param _longitude Longitude coordinate (decimal format, e.g., "-154.5").
    /// @return bytes Request hash as a byte array.
    function getGreenHouseGasInversionByMonth(
        string memory _date,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&date=",
                _date,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getGreenHouseGasInversionByMonthBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves air quality forecast values by level for a specific date.
    /// @dev Sends a request to Chainlink for air quality forecast data for a specific level and date.
    /// String types are used for all parameters to ensure compatibility with Chainlink jobs.
    /// @param _date Date of the data (format: "YYYY-MM-DD", e.g., "2021-10-04").
    /// @param _levelValue Level value (decimal format, e.g., "50").
    /// @param _gas Type of gas (e.g., "CO").
    /// @param _latitude Latitude coordinate (decimal format, e.g., "71.95").
    /// @param _longitude Longitude coordinate (decimal format, e.g., "335.15").
    /// @return bytes Request hash as a byte array.
    function getAirQualityForecastsValuesByLevel(
        string memory _date,
        string memory _levelValue,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&date=",
                _date,
                "&levelValue=",
                _levelValue,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getAirQualityForecastsValuesByLevelBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @dev Want to know why we use string types for variables everywhere? See the comment above.
    /// @notice Retrieves atmospheric composition values by level for a specific date.
    /// @dev Constructs and sends a Chainlink request for atmospheric composition data for a given date and level.
    /// String types are used for parameters to maintain a universal job structure across the Chainlink network.
    /// @param _date Date of the data (format: "YYYY-MM-DD", e.g., "2003-05-01").
    /// @param _level Measurement level (e.g., "Pressure").
    /// @param _levelValue Level value (decimal format, e.g., "7").
    /// @param _gas Type of gas (e.g., "CO2").
    /// @param _latitude Latitude coordinate (decimal format, e.g., "90").
    /// @param _longitude Longitude coordinate (decimal format, e.g., "0").
    /// @return bytes Request hash as a byte array.
    function getAtmosphericCompositionValuesByLevel(
        string memory _date,
        string memory _level,
        string memory _levelValue,
        string memory _gas,
        string memory _latitude,
        string memory _longitude
    ) public returns (bytes memory) {
        string memory parameters = string(
            abi.encodePacked(
                "&date=",
                _date,
                "&level=",
                _level,
                "&levelValue=",
                _levelValue,
                "&gas=",
                _gas,
                "&latitude=",
                _latitude,
                "&longitude=",
                _longitude
            )
        );
        RequestData memory requestData = RequestData({
            parameters: parameters,
            requestHashBytes: "",
            methodName: "getAtmosphericCompositionValuesByLevelBC"
        });
        return sendSectorRequest(requestData);
    }

    /// @notice Sends a sector request to Chainlink.
    /// @dev Builds a Chainlink request with the given data and sends it.
    /// @param requestData Data of the request to be sent.
    /// @return bytes memory representing the request hash.
    function sendSectorRequest(
        RequestData memory requestData
    ) private returns (bytes memory) {
        bytes32 requestHash = generatePseudoRandomBytes32();
        bytes memory requestHashBytes = abi.encodePacked(requestHash);
        lastSentHash = requestHash;

        if (requiredNodeConfirmations >= 1) {
            Chainlink.Request memory req1 = buildChainlinkRequest(
                jobId1,
                address(this),
                this.fulfillMultipleParameters.selector
            );
            addCopernicusRequestParameters(req1, requestData, requestHashBytes);
            sendChainlinkRequest(req1, fee);
        }

        if (requiredNodeConfirmations >= 2) {
            Chainlink.Request memory req2 = buildChainlinkRequest(
                jobId2,
                address(this),
                this.fulfillMultipleParameters.selector
            );
            addCopernicusRequestParameters(req2, requestData, requestHashBytes);
            sendChainlinkRequest(req2, fee);
        }

        if (requiredNodeConfirmations == 3) {
            Chainlink.Request memory req3 = buildChainlinkRequest(
                jobId3,
                address(this),
                this.fulfillMultipleParameters.selector
            );
            addCopernicusRequestParameters(req3, requestData, requestHashBytes);
            sendChainlinkRequest(req3, fee);
        }

        sentHashes[counter] = requestHashBytes;
        counter++;
        getResultBySentHash[requestHash] = FinalGasData({
            requestHash: requestHash,
            requestStatus: "Pending",
            methodName: requestData.methodName,
            multiplied: 0,
            timestamp: block.timestamp,
            ch4Value: 0,
            co2Value: 0,
            no2Value: 0,
            coValue: 0
        });
        return requestHashBytes;
    }

    function addCopernicusRequestParameters(
        Chainlink.Request memory req,
        RequestData memory requestData,
        bytes memory requestHashBytes
    ) private pure {
        req.add("methodName", requestData.methodName);
        req.addBytes("requestHash", requestHashBytes);
        req.add("parameters", requestData.parameters);
    }

    /// @notice Fulfillment function for multiple parameters from Chainlink.
    /// @dev Processes the data received from Chainlink nodes.
    /// @param requestId The ID of the request being fulfilled.
    /// @param requestHash Hash of the request.
    /// @param requestStatus Status of the request.
    /// @param methodName Method name associated with the request.
    /// @param multiplied A calculated value based on the request.
    /// @param co2 CO2 value.
    /// @param co CO value.
    /// @param ch4 CH4 value.
    /// @param no2 NO2 value.
    function fulfillMultipleParameters(
        bytes32 requestId,
        bytes memory requestHash,
        string memory requestStatus,
        string memory methodName,
        int256 multiplied,
        int256 co2,
        int256 co,
        int256 ch4,
        int256 no2
    ) public recordChainlinkFulfillment(requestId) {
        emit MultipleParametrsFulfilled(
            requestId,
            requestHash,
            requestStatus,
            methodName,
            multiplied,
            block.timestamp,
            co2,
            co,
            ch4,
            no2
        );

        bytes32 requestHashBytes32 = bytesToBytes32(requestHash);
        GasDataNode storage node = gasDataNodes[requestHashBytes32];

        if (node.count == 0) {
            node.ch4Value = ch4;
            node.co2Value = co2;
            node.no2Value = no2;
            node.coValue = co;
            node.count = 1;
        } else {
            bool isEqual = (node.ch4Value == ch4) &&
                (node.co2Value == co2) &&
                (node.no2Value == no2) &&
                (node.coValue == co);
            if (isEqual) {
                node.count += 1;
            }
        }

        if (node.count >= requiredNodeConfirmations) {
            FinalGasData storage finalData = getResultBySentHash[
                requestHashBytes32
            ];
            finalData.requestHash = requestHashBytes32;
            finalData.requestStatus = requestStatus;
            finalData.methodName = methodName;
            finalData.multiplied = multiplied;
            finalData.timestamp = block.timestamp;
            finalData.co2Value = co2;
            finalData.coValue = co;
            finalData.ch4Value = ch4;
            finalData.no2Value = no2;
            _lastRequestHash = requestHashBytes32;
            _lastRequestStatus = requestStatus;
            _lastMethodName = methodName;
            _lastTimestamp = block.timestamp;
            _lastMultipliedParametr = multiplied;
            _lastCo2Value = co2;
            _lastCoValue = co;
            _lastCh4Value = ch4;
            _lastNo2Value = no2;
        }
    }

    /// @notice Retrieves the latest result from the contract.
    /// @dev Provides the most recent data processed by the contract.
    function getLatestResult()
        public
        view
        virtual
        returns (
            bytes32 lastRequestHash,
            uint256 lastTimestamp,
            string memory lastRequestStatus,
            string memory lastMethodName,
            int256 lastMultipliedParametr,
            int256 lastCh4Value,
            int256 lastCo2Value,
            int256 lastNo2Value,
            int256 lastCoValue
        )
    {
        lastRequestHash = _lastRequestHash;
        lastTimestamp = _lastTimestamp;
        lastRequestStatus = _lastRequestStatus;
        lastMethodName = _lastMethodName;
        lastMultipliedParametr = _lastMultipliedParametr;
        lastCh4Value = _lastCh4Value;
        lastCo2Value = _lastCo2Value;
        lastNo2Value = _lastNo2Value;
        lastCoValue = _lastCoValue;
    }

    /// @notice Changes the job IDs used for Chainlink requests.
    /// @dev Allows the contract owner to update job IDs.
    /// @param _jobId1 New job ID for the first job.
    /// @param _jobId2 New job ID for the second job.
    /// @param _jobId3 New job ID for the third job.
    function changeJobId(
        string memory _jobId1,
        string memory _jobId2,
        string memory _jobId3
    ) public onlyOwner {
        jobId1 = stringToBytes32(_jobId1);
        jobId2 = stringToBytes32(_jobId2);
        jobId3 = stringToBytes32(_jobId3);
    }

    uint256 private nonce = 0;

    /// @notice Generates a pseudo-random bytes32 value. used as requestHash - a unique id for the request
    /// @dev Combines current block timestamp, sender, and nonce to create the value.
    /// @return bytes32 Pseudo-randomly generated bytes32 value.
    function generatePseudoRandomBytes32() private returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(block.timestamp, msg.sender, nonce)
        );
        nonce++;
        return hash;
    }

    /// @notice Updates the number of required node confirmations.
    /// @dev Allows the owner to set the number of confirmations for Chainlink nodes.
    /// @param _confirmations New number of required confirmations.
    function setRequiredNodeConfirmations(
        uint256 _confirmations
    ) public onlyOwner {
        require(
            _confirmations > 0 && _confirmations <= 3,
            "Confirmations should be between 1 and 3"
        );
        requiredNodeConfirmations = _confirmations;
    }

    modifier onlyWhitelisted() {
        require(
            whitelist[msg.sender],
            "Only whitelisted users can call this function"
        );
        _;
    }

    /// @notice Adds a user to the whitelist.
    /// @dev Allows the owner to whitelist a user address.
    /// @param _user Address of the user to be whitelisted.
    function addUserToWhitelist(address _user) public onlyOwner {
        require(_user != address(0), "Invalid address");
        whitelist[_user] = true;
    }

    /// @notice Removes a user from the whitelist.
    /// @dev Allows the owner to remove a user from the whitelist.
    /// @param _user Address of the user to be removed.
    function removeFromWhitelist(address _user) public onlyOwner {
        require(_user != address(0), "Invalid address");
        whitelist[_user] = false;
    }

    /// @notice Checks if a user is whitelisted.
    /// @dev Returns a boolean indicating if the user is on the whitelist.
    /// @param _user Address of the user to check.
    /// @return bool True if the user is whitelisted, false otherwise.
    function isWhitelisted(address _user) public view returns (bool) {
        return whitelist[_user];
    }

    /// @notice Withdraws LINK tokens from the contract.
    /// @dev Transfers the balance of LINK tokens to the message sender.
    function withdrawLink() public {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    /// @notice Converts a string to bytes32.
    /// @dev Used for converting string IDs to bytes32 format.
    /// @param source String to be converted.
    function stringToBytes32(
        string memory source
    ) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            // solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }

    /// @notice Converts bytes to bytes32.
    /// @dev Used for converting bytes array to bytes32 format.
    /// @param b Bytes array to be converted.
    /// @return bytes32 Converted bytes32 value.
    function bytesToBytes32(bytes memory b) private pure returns (bytes32) {
        require(b.length == 32, "Bytes length should be 32.");
        bytes32 out;
        for (uint256 i = 0; i < 32; i++) {
            out |= bytes32(b[i] & 0xFF) >> (i * 8);
        }
        return out;
    }
}
