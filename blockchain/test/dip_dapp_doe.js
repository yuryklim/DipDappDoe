const DipDappDoe = artifacts.require("./DipDappDoe.sol");
const LibString = artifacts.require("./LibString.sol");
let gamesInstance, libStringInstance;

contract('dipDappDoe', function(accounts) {
  it("should be deployed", async function () {
    gamesInstance = await DipDappDoe.deployed();
    assert.isOk(gamesInstance, "instance should not be null");
    assert.equal(typeof gamesInstance, "object", "Instance should be an object");

    // ...
});

// ...

// DipDappDoe.createGame

  it("should create a game with no money", async function () {
    gamesInstance = await DipDappDoe.deployed();
    libStringInstance = await LibString.deployed();
    var eventWatcher = gamesInstance.GameCreated();
    let hash = await libStringInstance.saltedHash.call(123, "my salt 1");

    await gamesInstance.createGame(hash, "John");

    assert.equal(await web3.eth.getBalance(gamesInstance.address).toNumber(), 0, "The contract should have registered a zero amount of ether owed to the players");

    let gamesIdx = await gamesInstance.getOpenGames.call();
    gamesIdx = gamesIdx.map(n => n.toNumber());
    assert.deepEqual(gamesIdx, [0], "Should have one game");

    const emittedEvents = await eventWatcher.get();
    assert.isOk(emittedEvents, "Events should be an array");
    assert.equal(emittedEvents.length, 1, "There should be one event");
    assert.isOk(emittedEvents[0], "There should be one event");
    assert.equal(emittedEvents[0].args.gameIdx.toNumber(), 0, "The game should have index zero");

    const gameIdx = gamesIdx[0];

    let [cells, status, amount, nick1, nick2, ...rest] = await gamesInstance.getGameInfo(gameIdx);
    cells = cells.map(n => n.toNumber());
    assert.deepEqual(cells, [0, 0, 0, 0, 0, 0, 0, 0, 0], "The board should be empty");
    assert.equal(status.toNumber(), 0, "The game should not be started");
    assert.equal(amount.toNumber(), 0, "The game should have no money");
    assert.equal(nick1, "John", "The player 1 should be John");
    assert.equal(nick2, "", "The player 2 should be empty");
    assert.deepEqual(rest, [], "The response should have 5 elements");

    let lastTransaction = await gamesInstance.getGameTimestamp(gameIdx);
    assert.isAbove(lastTransaction.toNumber(), 0, "The last timestamp should be set");

    let [player1, player2, ...rest3] = await gamesInstance.getGamePlayers(gameIdx);
    assert.equal(player1, accounts[0], "The address of player 1 should be set");
    assert.equal(player2, "0x0000000000000000000000000000000000000000", "The address of player 2 should be empty");
    assert.deepEqual(rest3, [], "The response should have 2 elements");
  });
});
