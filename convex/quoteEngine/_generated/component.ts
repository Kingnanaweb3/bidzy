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
    quotes: {
      clearAll: FunctionReference<"mutation", "internal", {}, any, Name>;
      clearJob: FunctionReference<
        "mutation",
        "internal",
        { jobKey: string },
        any,
        Name
      >;
      compare: FunctionReference<
        "query",
        "internal",
        { jobKey: string },
        any,
        Name
      >;
      confirm: FunctionReference<
        "mutation",
        "internal",
        {
          exclusions?: Array<string>;
          lineItems?: Array<{ amount?: number; label: string; note?: string }>;
          quoteId: string;
          total?: number;
        },
        any,
        Name
      >;
      invalidate: FunctionReference<
        "mutation",
        "internal",
        { jobKey: string; newTag: string; reason: string },
        any,
        Name
      >;
      listByJob: FunctionReference<
        "query",
        "internal",
        { jobKey: string },
        any,
        Name
      >;
      record: FunctionReference<
        "mutation",
        "internal",
        {
          currency?: string;
          exclusions?: Array<string>;
          inclusions?: Array<string>;
          jobKey: string;
          lineItems?: Array<{ amount?: number; label: string; note?: string }>;
          needsReview?: boolean;
          partyKey: string;
          partyName: string;
          rawText?: string;
          scopeTags?: Array<string>;
          sourceUrl?: string;
          total?: number;
        },
        any,
        Name
      >;
      revalidateAll: FunctionReference<
        "mutation",
        "internal",
        { jobKey: string },
        any,
        Name
      >;
    };
  };
