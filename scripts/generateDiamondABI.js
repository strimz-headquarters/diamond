const fs = require("fs");

async function main() {
  const basePath = "/contracts/facets/";
  let filePaths = fs.readdirSync("." + basePath);
  let abis = [];

  /// not facets
  //   let abstracts = ["Naira.sol"];

  //   for (path of abstracts) {
  //     const jsonFile = path.replace("sol", "json");
  //     let json = fs.readFileSync(`./out/${path}/${jsonFile}`);
  //     json = JSON.parse(json);
  //     let finalAbi = JSON.stringify(json.abi);
  //     fs.writeFileSync(`abis/${jsonFile}`, finalAbi);
  //     console.log(`ABI written to abis/${jsonFile}`);
  //   }

  for (path of filePaths) {
    const jsonFile = path.replace("sol", "json");
    let json = fs.readFileSync(`./out/${path}/${jsonFile}`);
    json = JSON.parse(json);
    abis.push(...json.abi);
  }
  let finalAbi = JSON.stringify(abis);
  fs.writeFileSync("abis/diamond.json", finalAbi);

  console.log("ABI written to abis/diamond.json");

  //* SENDING ABI TO FRONTEND

  // Define the paths
  //   const contractAbiPath = "../contract/abis/diamond.json";
  //   const frontendJsonPath = "../frontend/src/json/diamond.json";

  //   const diamondAbi = fs.readFileSync(contractAbiPath);

  //   fs.writeFileSync(frontendJsonPath, diamondAbi);

  //   console.log("Diamond ABI moved to frontend/src/json/diamond.json");
}

main().catch(console.log);
