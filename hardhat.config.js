require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
solidity: "0.8.20",
networks: {
    taiko: {
    url: String(process.env.URL_RPC),
    accounts: [String(process.env.PRIVATE_KEY)],
    }
}
};

