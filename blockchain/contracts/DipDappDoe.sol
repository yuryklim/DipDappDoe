pragma solidity ^0.4.24;

import "./LibString.sol";
contract DipDappDoe {
    // DATA
    struct Game {
        uint32 openListIndex;   // position in openGames[]
        uint8[9] cells;  // [123 / 456 / 789] containing [0 => nobody, 1 => X, 2 => O]
        
        // 0 => not started, 1 => player 1, 2 => player 2
        // 10 => draw, 11 => player 1 wins, 12 => player 2 wins
        uint8 status;
        
        uint amount;  // amount of money each user has sent

        address[2] players;
        string[2] nicks;
        uint lastTransaction; // timestamp => block number
        bool[2] withdrawn;

        bytes32 creatorHash;
        uint8 guestRandomNumber;
    }
    
    uint32[] openGames; // list of active games' id's
    mapping(uint32 => Game) gamesData; // data containers
    uint32 nextGameIdx;
    uint16 public timeout;
  
  // EVENTS
    event GameCreated(uint32 indexed gameIdx);
    event GameAccepted(uint32 indexed gameIdx, address indexed opponent);
    event GameStarted(uint32 indexed gameIdx, address indexed opponent);
    event PositionMarked(uint32 indexed gameIdx, address indexed opponent);
    event GameEnded(uint32 indexed gameIdx, address indexed opponent);

    // CALLABLE

    function getOpenGames() public view returns (uint32[]){
        return openGames;
    }

    function getGameInfo(uint32 gameIdx) public view 
    returns (uint8[9] cells, uint8 status, uint amount, string nick1, string nick2) {
        return (
            gamesData[gameIdx].cells,
            gamesData[gameIdx].status,
            gamesData[gameIdx].amount,
            gamesData[gameIdx].nicks[0],
            gamesData[gameIdx].nicks[1]
        );
    }

    function getGameTimestamp(uint32 gameIdx) public view 
    returns (uint lastTransaction) {
        return (gamesData[gameIdx].lastTransaction);
    }

    function getGamePlayers(uint32 gameIdx) public view 
    returns (address player1, address player2) {
        return (
            gamesData[gameIdx].players[0],
            gamesData[gameIdx].players[1]
        );
    }

    function getGameWithdrawals(uint32 gameIdx) public view 
    returns (bool player1, bool player2) {
        return (
            gamesData[gameIdx].withdrawn[0],
            gamesData[gameIdx].withdrawn[1]
        );
    }

    // OPERATIONS

    function createGame(bytes32 randomNumberHash, string nick) public payable returns (uint32 gameIdx) {
        require(nextGameIdx + 1 > nextGameIdx);

        gamesData[nextGameIdx].openListIndex = uint32(openGames.length);
        gamesData[nextGameIdx].creatorHash = randomNumberHash;
        gamesData[nextGameIdx].amount = msg.value;
        gamesData[nextGameIdx].nicks[0] = nick;
        gamesData[nextGameIdx].players[0] = msg.sender;
        gamesData[nextGameIdx].lastTransaction = now;
        openGames.push(nextGameIdx);

        gameIdx = nextGameIdx;
        emit GameCreated(nextGameIdx);
        
        nextGameIdx++;
    }

    function acceptGame(uint32 gameIdx, uint8 randomNumber, string nick) public payable {
        require(gameIdx < nextGameIdx);
        require(gamesData[gameIdx].players[0] != 0x0);
        require(msg.value == gamesData[gameIdx].amount);
        require(gamesData[gameIdx].players[1] == 0x0);
        require(gamesData[gameIdx].status == 0);

        gamesData[gameIdx].guestRandomNumber = randomNumber;
        gamesData[gameIdx].nicks[1] = nick;
        gamesData[gameIdx].players[1] = msg.sender;
        gamesData[gameIdx].lastTransaction = now;

        emit GameAccepted(gameIdx, gamesData[gameIdx].players[0]);

        // Remove from the available list (unordered)
        uint32 idxToDelete = uint32(gamesData[gameIdx].openListIndex);
        openGames[idxToDelete] = openGames[openGames.length - 1];
        gamesData[gameIdx].openListIndex = idxToDelete;
        openGames.length--;
    }

    function confirmGame(uint32 gameIdx, uint8 revealedRandomNumber, string revealedSalt) public {
        require(gameIdx < nextGameIdx);
        require(gamesData[gameIdx].players[0] == msg.sender);
        require(gamesData[gameIdx].players[1] != 0x0);
        require(gamesData[gameIdx].status == 0);

        bytes32 computedHash = hashNumber(revealedRandomNumber, revealedSalt);
        if(computedHash != gamesData[gameIdx].creatorHash){
            gamesData[gameIdx].status = 12;
            emit GameEnded(gameIdx, msg.sender);
            emit GameEnded(gameIdx, gamesData[gameIdx].players[1]);
            return;
        }
        gamesData[gameIdx].lastTransaction = now;

        // Define the starting player
        if((revealedRandomNumber ^ gamesData[gameIdx].guestRandomNumber) & 0x01 == 0){
            gamesData[gameIdx].status = 1;
            emit GameStarted(gameIdx, gamesData[gameIdx].players[1]);
        }
        else {
            gamesData[gameIdx].status = 2;
            emit GameStarted(gameIdx, gamesData[gameIdx].players[1]);
        }
    }

    function markPosition(uint32 gameIdx, uint8 cell) public {
        require(gameIdx < nextGameIdx);
        require(cell <= 8);

        uint8[9] storage cells = gamesData[gameIdx].cells;
        require(cells[cell] == 0);

        if(gamesData[gameIdx].status == 1){
            require(gamesData[gameIdx].players[0] == msg.sender);

            cells[cell] = 1;
            emit PositionMarked(gameIdx, gamesData[gameIdx].players[1]);
        }
        else if(gamesData[gameIdx].status == 2){
            require(gamesData[gameIdx].players[1] == msg.sender);
            
            cells[cell] = 2;
            emit PositionMarked(gameIdx, gamesData[gameIdx].players[0]);
        }
        else {
            revert();
        }

        gamesData[gameIdx].lastTransaction = now;


        // Board indexes:
        //    0 1 2
        //    3 4 5
        //    6 7 8

        // Detect a winner:
        // 0x01 & 0x01 & 0x01 != 0 => WIN
        // 0x02 & 0x02 & 0x02 != 0 => WIN
        
        // 0x01 & 0x01 & 0x02 == 0 => Diverse row
        // 0x01 & 0x02 & 0x02 == 0
        // ...

        if((cells[0] & cells [1] & cells [2] != 0x0) || (cells[3] & cells [4] & cells [5] != 0x0) ||
        (cells[6] & cells [7] & cells [8] != 0x0) || (cells[0] & cells [3] & cells [6] != 0x0) ||
        (cells[1] & cells [4] & cells [7] != 0x0) || (cells[2] & cells [5] & cells [8] != 0x0) ||
        (cells[0] & cells [4] & cells [8] != 0x0) || (cells[2] & cells [4] & cells [6] != 0x0)) {
            // winner
            gamesData[gameIdx].status = 10 + cells[cell];  // 11 or 12
            emit GameEnded(gameIdx, gamesData[gameIdx].players[0]);
            emit GameEnded(gameIdx, gamesData[gameIdx].players[1]);
        }
        else if(cells[0] != 0x0 && cells[1] != 0x0 && cells[2] != 0x0 && 
            cells[3] != 0x0 && cells[4] != 0x0 && cells[5] != 0x0 && cells[6] != 0x0 && 
            cells[7] != 0x0 && cells[8] != 0x0) {
            // draw
            gamesData[gameIdx].status = 10;
            emit GameEnded(gameIdx, gamesData[gameIdx].players[0]);
            emit GameEnded(gameIdx, gamesData[gameIdx].players[1]);
        }
        else {
            if(cells[cell] == 1){
                gamesData[gameIdx].status = 2;
            }
            else if(cells[cell] == 2){
                gamesData[gameIdx].status = 1;
            }
            else {
                revert();
            }
        }
    }

    function withdraw(uint32 gameIdx) public {
        require(gameIdx < nextGameIdx);
        require(gamesData[gameIdx].amount > 0);

        uint8 status = gamesData[gameIdx].status;

        if(status == 0) {
            require((now - gamesData[gameIdx].lastTransaction) > timeout);
            
            // Player 1 cancels the non-accepted game
            if(gamesData[gameIdx].players[0] == msg.sender) {
                // checking !withdrawn[0] is redundant, status would not be 0
                require(gamesData[gameIdx].players[1] == 0x0);

                gamesData[gameIdx].withdrawn[0] = true;
                gamesData[gameIdx].status = 10; // consider it ended in draw
                msg.sender.transfer(gamesData[gameIdx].amount);
                
                // The game was open
                // Remove from the available list (unordered)
                uint32 openListIdxToDelete = uint32(gamesData[gameIdx].openListIndex);
                openGames[openListIdxToDelete] = openGames[openGames.length - 1];
                gamesData[gameIdx].openListIndex = openListIdxToDelete;
                openGames.length--;

                emit GameEnded(gameIdx, msg.sender);
            }
            // Player 2 claims the non-confirmed game
            else if(gamesData[gameIdx].players[1] == msg.sender) {
                // checking !withdrawn[1] is redundant, status would not be 0

                gamesData[gameIdx].withdrawn[1] = true;
                gamesData[gameIdx].status = 12; // consider it won by P2
                msg.sender.transfer(gamesData[gameIdx].amount * 2);
            
                // The game was not open: no need to clean it
                // from the openGames[] list

                emit GameEnded(gameIdx, msg.sender);
            }
            else {
                revert();
            }
        }
        else if(status == 1) {
            // player 2 claims
            require(gamesData[gameIdx].players[1] == msg.sender);
            require(now - gamesData[gameIdx].lastTransaction > timeout);

            gamesData[gameIdx].withdrawn[1] = true;
            gamesData[gameIdx].status = 12;
            msg.sender.transfer(gamesData[gameIdx].amount * 2);

            emit GameEnded(gameIdx, gamesData[gameIdx].players[0]);
        }
        else if(status == 2){
            // player 1 claims
            require(gamesData[gameIdx].players[0] == msg.sender);
            require(now - gamesData[gameIdx].lastTransaction > timeout);

            gamesData[gameIdx].withdrawn[0] = true;
            gamesData[gameIdx].status = 11;
            msg.sender.transfer(gamesData[gameIdx].amount * 2);

            emit GameEnded(gameIdx, gamesData[gameIdx].players[1]);
        }
        else if(status == 10){
            if(gamesData[gameIdx].players[0] == msg.sender){
                require(!gamesData[gameIdx].withdrawn[0]);

                gamesData[gameIdx].withdrawn[0] = true;
                msg.sender.transfer(gamesData[gameIdx].amount);
            }
            else if(gamesData[gameIdx].players[1] == msg.sender){
                require(!gamesData[gameIdx].withdrawn[1]);

                gamesData[gameIdx].withdrawn[1] = true;
                msg.sender.transfer(gamesData[gameIdx].amount);
            }
            else {
                revert();
            }
        }
        else if(status == 11){
            require(gamesData[gameIdx].players[0] == msg.sender);
            require(!gamesData[gameIdx].withdrawn[0]);

            gamesData[gameIdx].withdrawn[0] = true;
            msg.sender.transfer(gamesData[gameIdx].amount * 2);
        }
        else if(status == 12){
            require(gamesData[gameIdx].players[1] == msg.sender);
            require(!gamesData[gameIdx].withdrawn[1]);

            gamesData[gameIdx].withdrawn[1] = true;
            msg.sender.transfer(gamesData[gameIdx].amount * 2);
        }
        else {
            revert();
        }
}

    // PUBLIC HELPER FUNCTIONS
    
    function hashNumber(uint8 randomNumber, string salt) public pure returns (bytes32) {
        return LibString.saltedHash(randomNumber, salt);
    }

    // DEFAULT
    
    function () public payable {
        revert();
    }
}
