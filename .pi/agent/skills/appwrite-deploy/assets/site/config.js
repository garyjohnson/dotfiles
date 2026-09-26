// Runtime config for the demo site. NO SECRETS here — the site uses per-user
// sessions (Account), not an API key. Commit this file (it's not sensitive).
//
// Fill in your Appwrite project + resource IDs, then redeploy.
window.APPWRITE_CONFIG = {
  endpoint: "https://appwrite.app.usefulbits.io/v1",
  projectId: "<PROJECT_ID>",
  databaseId: "main",
  tableId: "messages",
  bucketId: "uploads",
  topicId: "activity",
  functionId: "demo-fn",
};
