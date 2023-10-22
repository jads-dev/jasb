import { Logging } from "../logging.js";
import { Server } from "../model.js";

// The result of executing a task.
export interface Result {
  // If the task is finished and should not be executed again.
  finished: boolean;
}

// The result of executing a task that only runs once.
export interface SingleRunResult extends Result {
  finished: true;
}

// A background task, executed without a request.
export interface Task<TResult extends Result = Result> {
  name: string;
  details: object;
  execute: (
    server: Server.State,
    logger: Logging.Logger,
    meta: { iteration: number },
  ) => Promise<TResult>;
}

export * as Tasks from "./tasks.js";
