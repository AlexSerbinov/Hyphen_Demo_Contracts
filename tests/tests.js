const hre = require("hardhat");
const { ethers } = hre;

describe("BlockchainEndpointsDemoV3 Contract Tests", function () {
  let blockchainEndpointsDemoV3;
  let GAS_PRICE, GAS_LIMIT;

  before(async function () {
    const existingContractAddress = "0x23b4eEd3721557a4de02E7333B1E6904C283FEdf";
    const BlockchainEndpointsDemoV3 = await ethers.getContractFactory("BlockchainEndpointsDemoV3");
    blockchainEndpointsDemoV3 = BlockchainEndpointsDemoV3.attach(existingContractAddress);

    GAS_PRICE = ethers.utils.parseUnits("35", "gwei");
    GAS_LIMIT = ethers.utils.hexlify(1500000);
  });

  async function waitForResponse(methodName, gas, timeout) {
    let startTime = Date.now();
    let responseReceived = false;

    while (Date.now() - startTime < timeout) {
      const result = await blockchainEndpointsDemoV3.getLatestResult();
      console.log(`${result.lastMethodName}, Gas: ${gas}, Response Time: ${(Date.now() - startTime) / 1000} of ${timeout / 1000} sec`);

      if (result.lastMethodName === methodName + "BC") {
        const gases = ["co2", "co", "no2", "ch4"];
        for (const g of gases) {
          if (result[`last${g.charAt(0).toUpperCase() + g.slice(1)}Value`].toString() === "-999") {
            throw new Error(`Error: Response is -999 for ${gas} in method ${methodName}`);
            // Chainlink cannot yet return status codes to smart contracts.
            // Therefore, we use the simplest option, if the value is "-999" - it means
            // there was an error during the request execution.
            // The detailed error will need to be checked on the adapter.
          }
          if (result[`last${g.charAt(0).toUpperCase() + g.slice(1)}Value`].toString() !== "0") {
            responseReceived = true;
            break;
          }
        }
        if (responseReceived) break;
      }
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }

    if (!responseReceived) {
      throw new Error(`No Response: Timed out after ${timeout / 1000} sec for method ${methodName} with gas ${gas}`);
    }
  }

  function createTest(methodName, testParams, gas, timeout) {
    it(`should correctly handle ${methodName} method`, async function () {
      await blockchainEndpointsDemoV3[methodName](...testParams, { gasLimit: GAS_LIMIT, gasPrice: GAS_PRICE });
      await waitForResponse(methodName, gas, timeout);
    });
  }

  createTest("getReanalysisValuesByLevel", ["2003-02-01", "Pressure", "5", "co", "90", "1.5"], "co", 100000);
  createTest("getAtmosphericCompositionValuesByLevel", ["2015-01-06", "Pressure", "50", "CH4", "90", "0"], "CH4", 45000);
  createTest("getGreenHouseValuesByLevel", ["2003-05-01", "Pressure", "7", "co2", "90", "0"], "co2", 120000);
  createTest("getAirReanalysesValuesByHour", ["2016-02-01", "0", "co", "30", "-25"], "co", 200000);
  createTest("getEmissionBioValuesByMonth", ["2000", "1", "ch4", "0", "-56.5", "-68.75"], "ch4", 25000);
  createTest("getAirQualityForecastsValuesByLevel", ["2021-10-04", "50", "CO", "71.95", "335.15"], "CO", 25000);
  createTest("getEmissionAnthroValuesBySector", ["2005", "1", "sum", "CO2", "-77.85", "166.35"], "CO2", 40000);
  createTest("getEmissionAviaValuesByLevel", ["2000", "3", "CO2", "4.575", "-55.75", "-67.75"], "CO2", 30000);
  createTest("getEmissionTermValuesByMonth", ["2000", "1", "ch4", "52.25", "-110.75"], "ch4", 20000);
  createTest("getGreenHouseMonthlyValuesByMonth", ["2003", "5", "co2", "7", "90", "0"], "co2", 20000);
  createTest("getGreenHouseGasInversionByMonth", ["2018-02-08", "CH4", "-89", "-154.5"], "CH4", 20000);
  createTest("getReanalysisMonthlyValuesByMonth", ["2003", "2", "Model", "60", "co", "90", "1.5"], "co", 20000);
  createTest("getEmissionShipValuesByDay", ["2001", "3", "12", "CO2", "82.25", "-114"], "CO2", 55000);
});
