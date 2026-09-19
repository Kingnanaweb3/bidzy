/* eslint-disable */
/**
 * Generated `ComponentApi` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type { FunctionReference } from "convex/server";

/**
 * A utility for referencing a Convex component's exposed API.
 *
 * Useful when expecting a parameter like `components.myComponent`.
 * Usage:
 * ```ts
 * async function myFunction(ctx: QueryCtx, component: ComponentApi) {
 *   return ctx.runQuery(component.someFile.someQuery, { ...args });
 * }
 * ```
 */
export type ComponentApi<Name extends string | undefined = string | undefined> =
  {
    licences: {
      clearAll: FunctionReference<"mutation", "internal", {}, any, Name>;
      forJob: FunctionReference<
        "query",
        "internal",
        { partyKeys: Array<string> },
        any,
        Name
      >;
      get: FunctionReference<
        "query",
        "internal",
        { partyKey: string },
        any,
        Name
      >;
      history: FunctionReference<
        "query",
        "internal",
        { partyKey: string },
        any,
        Name
      >;
      record: FunctionReference<
        "mutation",
        "internal",
        {
          confident: boolean;
          evidence?: string;
          expiresOn?: string;
          licenceNumber?: string;
          partyKey: string;
          partyName: string;
          registryName?: string;
          sourceUrl?: string;
          status: "valid" | "expired" | "not_found" | "unknown";
        },
        any,
        Name
      >;
      seed: FunctionReference<
        "mutation",
        "internal",
        { partyKey: string; partyName: string; region?: string },
        any,
        Name
      >;
    };
  };
