---
name: premium-app-craft
description: AI guidelines for crafting premium, highly polished app experiences and eliminating generic AI slop generations.
---

# Instructions

When designing, architecting, or writing code for applications, you must prioritize "craft" and "feel." The first output is the starting line, not the finish line. Always ask: "How can this be better?"

Apply the following principles to ensure the app feels premium and less sloppy:

## 1. Intentional, Refined Animations
*   **Never settle for instant state changes.** If a background process (like an AI summary or data fetch) completes, do not simply snap the new text onto the screen.
*   **Beyond Toasts:** A toast notification is better than nothing, but a contextual, visually engaging animation is premium. 
*   **Implementation:** Utilize fluid animations that convey the action (e.g., a subtle gradient sweep, smooth size transitions). Ensure state updates (whether through standard controllers or reactive streams like GetX) trigger clear visual feedback, not just raw data replacements.

## 2. Distinctive Illustrations & Assets
*   **Avoid the "Default AI" Look:** Generic, one-shot AI illustrations make an app feel cheap and generic. 
*   **Iterate and Animate:** Mix styles and iterate heavily on prompts (or work with human artists). Aim for an art style that looks hand-crafted. Use animated loops for empty states and onboarding screens to breathe life into the app.

## 3. Elevated Custom Interactions (UI Craft)
*   **Bypass System Defaults:** Avoid relying solely on default OS popups or standard system sheets if a custom inline experience feels smoother. For example, instead of firing off a basic system camera intent, build a seamless, performant inline camera view directly within the app's native UI flow.
*   **Layer Over Time:** It is acceptable to ship system defaults in version 1, but always plan to elevate these interactions in subsequent updates.

## 4. Invisible Craft & Contextual Polish
*   **Anticipate Edge Cases:** Premium is often felt in what the user *doesn't* see. Build invisible features that pleasantly surprise the user by making the app work flawlessly in complex scenarios.
*   **Contextual Data:** Use available context (like location, time, or relational data stored in the backend, e.g., PostgreSQL/Supabase) to silently improve user inputs. For instance, if relying on text search or dictation, quietly fetch contextual variables (like nearby venues or user history) to boost accuracy and handle edge cases automatically.

## 5. The Iteration Mandate
*   Do not accept the first draft of any feature, animation, or design. 
*   Push for the 1% details that 99% of users might not consciously identify, but will absolutely feel when using the app.
