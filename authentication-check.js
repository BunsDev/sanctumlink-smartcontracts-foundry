//////////////////////////////////////////////////////////////////
//////////////////////// USING WEB3.JS ///////////////////////////
/////////////////////////////////////////////////////////////////

const AUTH_TIMEOUT = 10800; // 3 hours in seconds
let authenticationTimestamp = 0;

// Function to authenticate the user
async function authenticateUser() {
    const accounts = await web3.eth.getAccounts();
    const account = accounts[0];

    await contract.methods.authenticate().send({ from: account });
    authenticationTimestamp = Math.floor(Date.now() / 1000); // Store current timestamp in seconds
}

// Function to check if the user is still authenticated
function isAuthenticated() {
    const currentTime = Math.floor(Date.now() / 1000);
    return (currentTime - authenticationTimestamp) <= AUTH_TIMEOUT;
}

// Function to force re-authentication
async function forceReauthentication() {
    authenticationTimestamp = 0; // Clear the authentication timestamp

    // Optionally, clear any stored data or states related to authentication
    alert('Your session has expired. Please re-authenticate.');

    // Clear the provider state (disconnect)
    if (window.ethereum && window.ethereum.disconnect) {
        await window.ethereum.disconnect();
    }

    // Trigger the wallet to reconnect
    authenticateUser();
}

// Function to periodically check authentication status
function checkAuthStatus() {
    if (!isAuthenticated()) {
        forceReauthentication();
    }
}

// Set an interval to check authentication status every minute
setInterval(checkAuthStatus, 60000);

// Optionally call this function on page load to check authentication status
window.onload = checkAuthStatus;


//////////////////////////////////////////////////////////////////
///////////////////// USING ETHERS.JS ///////////////////////////
/////////////////////////////////////////////////////////////////

const AUTH_TIMEOUT = 10800; // 3 hours in seconds
let authenticationTimestamp = 0;

// Function to authenticate the user
async function authenticateUser() {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const signer = provider.getSigner();
    const account = await signer.getAddress();

    const contract = new ethers.Contract(contractAddress, abi, signer);
    await contract.authenticate();
    authenticationTimestamp = Math.floor(Date.now() / 1000); // Store current timestamp in seconds
}

// Function to check if the user is still authenticated
function isAuthenticated() {
    const currentTime = Math.floor(Date.now() / 1000);
    return (currentTime - authenticationTimestamp) <= AUTH_TIMEOUT;
}

// Function to force re-authentication
async function forceReauthentication() {
    authenticationTimestamp = 0; // Clear the authentication timestamp

    // Optionally, clear any stored data or states related to authentication
    alert('Your session has expired. Please re-authenticate.');

    // Clear the provider state (disconnect)
    if (window.ethereum && window.ethereum.disconnect) {
        await window.ethereum.disconnect();
    }

    // Trigger the wallet to reconnect
    authenticateUser();
}

// Function to periodically check authentication status
function checkAuthStatus() {
    if (!isAuthenticated()) {
        forceReauthentication();
    }
}

// Set an interval to check authentication status every minute
setInterval(checkAuthStatus, 60000);

// Optionally call this function on page load to check authentication status
window.onload = checkAuthStatus;
