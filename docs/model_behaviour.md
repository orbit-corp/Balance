# Model Behaviour

1. When context is extremely long, the model takes multiple turns(each one loading the full context) and thus taking too long to record a transaction. How to solve this would be automatic compacting but i may need to try other options
2. The ai generated content must be correctly formatted
3. If a chat has already been started by one model and for some reason that model goes out of service, we mask that model as unavailable and the user can only use active model to start a new chat (This is to preserve context and maintain performance)
4. We will test harness performance across different models (part of our reserach push)
5. How should reversals happen? should the current approach work or the model be smarter
6. if a transaction has already been reversed then we should not re-reverse it. Waste of time and effort
7. The system should be able to tell you what your most expensive transaction is - It should not loop through the entire system instead it will query the db for JEs and order DESC then return the first txn
8. harness improvements here https://medium.com/@visrow/harness-engineering-vs-prompt-engineering-vs-context-engineering-explained-0423b692c87d
9. state machine integration (aasm)
10. When deployed, you can download the underlying model. consult https://github.com/vishalmysore/harnessEngineeringDemo. The goal is to make this the easy default in dev mode. In prod we will use the prod models with a great harness.
11. Strategy for account classification
12. Implement rotating thinking words
13. Use RAD with Spec-Driven-Development
14. The system should not end conversation. Rather it proposes a tool, wait for user action and continue
