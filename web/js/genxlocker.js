var web3Lib;
var currentAccount = null;
var errMessage;
var dappContract;
var walletConfirmed = false;

function detectWallet()
{
    if(typeof window.ethereum !== 'undefined'){
        return true;
    }else{
        return false;
    }
}

async function connectWallet()
{
	if(window.currentAccount !== null){
		//already connected
		return;
    }
    let okay = false;
    if(!detectWallet()){
        document.getElementById("statusbox").innerHTML = " Browser wallet not detected";
    }else{
        window.web3Lib = new web3Lib(window.ethereum);
        try{
            await window.ethereum.enable();
            okay = true;
        }catch(error){
            if(error.code === 4001){
                window.errMessage = "Connection rejected";
            }else if(error.code === 4002){
                window.errMessage = "Metamask is disabled";
            }else{
                window.errMessage = "A error occurred";
            }
            document.getElementById("statusbox").innerHTML = window.errMessage;
        }
    }
    if(okay){
        accounts = await window.web3Lib.eth.getAccounts();
        //accounts = await windows.ethereum.request({method: 'eth_accounts'});
        window.currentAccount = accounts[0];
        if(window.currentAccount !== null){
            document.getElementById("connectbtn").innerText = "Connected";
            document.getElementById("statusbox").innerHTML = window.currentAccount;
        }else{
            document.getElementById("connectbtn").innerText = "Connect";
            document.getElementById("statusbox").innerHTML = "Connect your Wallet";
        }
        otherSetup();
    }
}

async function otherSetup()
{
    //Add listeners
    window.ethereum.on('disconnect',() => {
        document.getElementById("connectbtn").innerText = "Connect";
        document.getElementById("statusbox").innerHTML = "Connect your Wallet";
        window.errMessage = "";
        window.currentAccount = null;
    });
    window.ethereum.on('accountsChange',(accounts) => {
        //handle account change
        if(window.currentAccount != accounts[0]){
            document.getElementById("connectbtn").innerText = "Connected";
            document.getElementById("statusbox").innerHTML = "Active account has changed";
        }else{
            document.getElementById("connectbtn").innerText = "Connected";
            document.getElementById("statusbox").innerHTML = window.currentAccount;
        }
    });

    window.dappContract = new window.web3Lib.eth.Contract(window.ABI_FILE, window.DAPP_C_A);
    //check if current chain is bsc testnet
    if(!checkNetwork()){
        await switchChain();
    }
}

async function checkNetwork()
{
    const targetNet = '0x61';
    const curNet = await window.ethereum.request({method: 'eth_chainId'});
    return (targetNet == curNet);
}

function signWallet()
{
    window.web3Lib.personal.sign(window.web3Lib.fromUtf8("GenXLocker - Sign to confirm your wallet"), window.currentAccount, (error) => {
        if(error !== null){
            //Not Signed
            window.walletConfirmed = false;
        }else{
            window.walletConfirmed = true;
        }
    })
}

async function switchChain()
{
    try {
        //switch to BNB testnet
        await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{chainId: '0x61'}]
        });
    } catch (switchError) {
        if(switchError.code === 4902){
            //chain han't been added
            try {
                await window.ethereum.request({
                    method: 'wallet_addEthereumChain',
                    params: [{chainId: '0x61',
                            chainName: "BSC Testnet",
                            rpcUrls: ['https://bsc-testnet.drpc.org/'],
                        },],
                });
            } catch (addError) {
                //handle add error
                alert(addError.message);
            }
        }else{
            //handle other swicth errors
            alert(switchError.message);
        }
    }
}

async function loadTokens()
{
	if(window.currentAccount !== null && window.currentAccount !== 'undefined'){
        //a wallet is currently connected
        document.getElementById("connectbtn").innerText = " Connected ";
        document.getElementById("statusbox").innerHTML = window.currentAccount;
		const tokenList = await window.dappContract.methods.getStakeTokens().call();
		let options;
		tokenList.map((op,i) => {
			options += '<option value="${op}">"${op}"</option>';
		});
		document.getElementById("tknIn").innerHTML = options;
    }
}

async function listStakes()
{
	if(window.currentAccount !== null && window.currentAccount !== 'undefined'){
        //a wallet is currently connected
        document.getElementById("connectbtn").innerText = " Connected ";
        document.getElementById("statusbox").innerHTML = window.currentAccount;
		//read and display portfolio data
		const stakeData = await window.dappContract.methods.getStakingData(window.currentAccount).call({from: window.currentAccount});
		let myTable =document.getElementById("staketable");
		myTable.deleteRows();
		for(let element of stakeData){
			var row = myTable.insertRow();
			td = row.insertCell();
			cellText = document.createTextNode(element["lockedToken"]);
			td.appendChild(cellText);
			td = row.insertCell();
			cellText = document.createTextNode(element["lockedAmount"]);
			td.appendChild(cellText);
			td = row.insertCell();
			theDate = new Date(element["startTime"]);
			cellText = document.createTextNode(theDate.toDateString());
			td.appendChild(cellText);
			td = row.insertCell();
			theDate = new Date(element["endTime"]);
			cellText = document.createTextNode(theDate.toDateString());
			td.appendChild(cellText);
			td = row.insertCell();
			cellText = document.createTextNode(element["stakeDuration"]);
			td.appendChild(cellText);
			td = row.insertCell();
			cellText = document.createTextNode(element["stakeAPY"]);
			td.appendChild(cellText);
			td = row.insertCell();
			cellText = document.createTextNode(element["computedRewards"]);
			td.appendChild(cellText);
			let stakeStatus = "Active";
			if(element["lockState"] !== true){
				stakeStatus = "Expired";
			}
			td = row.insertCell();
			cellText = document.createTextNode(stakeStatus);
			td.appendChild(cellText);

			td = row.insertCell();
			if(element["lockState"] !== true){
				stakeStatus = "Expired";
				var btn = "<input type='button' onclick='unstake(" + element["internalIndex"] + ")' value='Unstake' />";
				cellText = document.createTextNode(btn);
				td.appendChild(cellText);
			}else{
				//stake is still active so can't unstake
				cellText = document.createTextNode("&nbsp;");
				td.appendChild(cellText);
			}       
		}
	}
}

async function doStake()
{
    var dataForm = new FormData(document.getElementById("stakeform"));
    var amt = dataForm.get("amtIn");
    //check if amount is a number
    let valid = (typeof amt === 'number' && !Number.isNaN(amt));
    if(!valid){
        window.errMessage = "Only numeric values are accepted for amount";
    }else{
		if(window.currentAccount !== null && window.currentAccount !== 'undefined'){
			//a wallet is currently connected
			document.getElementById("connectbtn").innerText = " Connected ";
			document.getElementById("statusbox").innerHTML = window.currentAccount;
			
			const gasEst = await window.dappContract.methods.newLock(dataForm.get("tknIn"),dataForm.get("daysIn"),amt,dataForm.get("apyIn")).estimateGas();
			const gasCost = await window.web3Lib.eth.getGasPrice();
			const nonce = await window.web3Lib.eth.getTransactionCount(window.currentAccount);
			let selectElem = document.getElementById("tknIn");
			let tkName = selectElem.value;
			//tkName = selectElem.options[selectElem.selectedIndex].value;
			const trx = {
				from: window.currentAccount, to: window.DAPP_C_A, gas: gasEst, gasPrice: gasCost, nonce: nonce,
				data: window.dappContract.methods.newLock(tkName,dataForm.get("daysIn"),amt,dataForm.get("apyIn")).encodeABI(),
			};
			/*
			const trx = {
				from: window.currentAccount, to: window.DAPP_C_A, gas: gasEst, gasPrice: gasCost, nonce: nonce,
				data: window.dappContract.methods.newLock(dataForm.get("tknIn"),dataForm.get("daysIn"),amt,dataForm.get("apyIn")).encodeABI(),
			};*/
			window.ethereum.request({method: 'eth_sendTransaction', params: [trx],})
			.then((result) => {window.errMessage = "Status: Success<br>Transaction Hash: " + result;})
			.catch((error) => {window.errMessage = "Status: Failed<br>" + error.message;});
		}else{
			window.errMessage = "You need to connect to a wallet first!";
		}
    }
    document.getElementById("msgbox").innerHTML = window.errMessage;
}

async function unstake(lockId)
{
    const gasEst = await window.dappContract.methods.unlockStake(lockId).estimateGas();
    const gasCost = await window.web3Lib.eth.getGasPrice();
    const nonce = await window.web3Lib.eth.getTransactionCount(window.currentAccount);
    const trx = {
        from: window.currentAccount, to: window.DAPP_C_A, gas: gasEst, gasPrice: gasCost, nonce: nonce,
        data: window.dappContract.methods.unlockStake(lockId).encodeABI(),
        };
    window.ethereum.request({method: 'eth_sendTransaction', params: [trx],})
        .then((result) => {window.errMessage = "Status: Success<br>Transaction Hash: " + result;})
        .catch((error) => {window.errMessage = "Status: Failed<br>" + error.message;});
    document.getElementById("msgbox").innerHTML = window.errMessage;
}

async function newStakeToken()
{
    var dataForm = new FormData(document.getElementById("tokenform"));
    if(dataForm.get("nameIn") == "" || dataForm.get("caIn") == ""){
        document.getElementById("msgbox").innerHTML = "All data fields are required";
    }else{
		if(window.currentAccount !== null && window.currentAccount !== 'undefined'){
			//a wallet is currently connected
			document.getElementById("connectbtn").innerText = " Connected ";
			document.getElementById("statusbox").innerHTML = window.currentAccount;
			
			const gasEst = await window.dappContract.methods.addStakeToken(dataForm.get("nameIn"),dataForm.get("caIn")).estimateGas();
			const gasCost = await window.web3Lib.eth.getGasPrice();
			const nonce = await window.web3Lib.eth.getTransactionCount(window.currentAccount);
			const trx = {
				from: window.currentAccount, to: window.DAPP_C_A, gas: gasEst, gasPrice: gasCost, nonce: nonce,
				data: window.dappContract.methods.addStakeToken(dataForm.get("nameIn"),dataForm.get("caIn")).encodeABI(),
			};
			window.ethereum.request({method: 'eth_sendTransaction', params: [trx],})
			.then((result) => {window.errMessage = "Status: Success<br>Transaction Hash: " + result;})
			.catch((error) => {window.errMessage = "Status: Failed<br>" + error.message;});
		}
    }
    document.getElementById("msgbox").innerHTML = window.errMessage;
}

function checkWalletConnect()
{
    if(window.currentAccount !== null && window.currentAccount !== 'undefined'){
        //a wallet is currently connected
        document.getElementById("connectbtn").innerText = " Connected ";
        document.getElementById("statusbox").innerHTML = window.currentAccount;
    }
}