import { Logging } from "../logging.js";
import { Server } from "../model.js";

// The result of executing a task.
export interface Result {
  // If the task is finished and should not be executed again.
  finished: boolean;
}

// A background task, executed without a request.
export type Task = (
  server: Server.State,
  logger: Logging.Logger,
  meta: { iteration: number },
) => Promise<Result>;

export * as Tasks from "./tasks.js";
