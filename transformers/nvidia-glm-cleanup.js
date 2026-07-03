const REQUEST_DELAY_MS = 5000;

let requestQueue = Promise.resolve();
let nextRequestAt = 0;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForRequestSlot() {
  const currentTurn = requestQueue.then(async () => {
    const waitMs = Math.max(0, nextRequestAt - Date.now());
    if (waitMs > 0) {
      await sleep(waitMs);
    }

    nextRequestAt = Date.now() + REQUEST_DELAY_MS;
  });

  requestQueue = currentTurn.catch(() => {});
  return currentTurn;
}

class NvidiaGlmCleanupTransformer {
  name = "nvidia-glm-cleanup";

  async transformRequestIn(request) {
    await waitForRequestSlot();

    const body = { ...request };
    delete body.reasoning;
    return body;
  }

  async transformResponseOut(response) {
    return response;
  }
}

module.exports = NvidiaGlmCleanupTransformer;
