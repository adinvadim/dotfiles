# HTML fallback

Use this branch when the current decision depends on runtime evidence that
Paper screens, state sequences, annotated flows, and diagrams cannot provide:
motion timing, direct manipulation, keyboard behavior, browser layout behavior,
or a similarly executable interaction. The executable prototype replaces the
Paper fork for this question; it does not permit a text-only interview.

1. State the exact runtime question and why the Paper representation is
   insufficient.
2. Build the smallest self-contained HTML prototype in a temporary directory
   outside the repository. Keep it read-only and use realistic data.
3. Expose only the variants needed for the current question and make their state
   visible after every interaction.
4. Open it in a browser and give the user one command or URL for comparison.
   Verify every labeled variant is runnable and visible.
5. Only after the user can compare the variants, ask one question referencing
   their labels with a recommended answer, then wait. Do not ask any preliminary
   clarification question.
6. After the answer, encode the chosen state or flow back into the accepted Paper
   baseline and resume the visual decision loop.

The branch is complete when Paper again contains the accepted decision and the
repository remains unchanged.
