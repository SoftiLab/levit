// Reactive state store using Svelte 5 runes
import type { ReactiveItem, ServerMessage } from '../types';
import { onMessage } from './websocket.svelte';

// Export reactive state object directly
export const reactiveState = $state<{
    state: Map<string, ReactiveItem>;
    history: Map<string, ReactiveItem[]>;
    updateCounts: Map<string, number>;
}>({
    state: new Map(),
    history: new Map(),
    updateCounts: new Map()
});

// Initialize message handler
onMessage((message: ServerMessage) => {
    switch (message.type) {
        case 'init':
            reactiveState.state = new Map();
            reactiveState.history = new Map();
            reactiveState.updateCounts = new Map();
            (message.reactive || []).forEach((item) => {
                if (item.id) {
                    reactiveState.state.set(item.id, item);
                }
            });
            break;

        case 'event':
            if (message.data) {
                const data = message.data;
                const type = data.type;

                // Handle Batch Events
                if (type === 'batch' && data.entries) {
                    const newState = new Map(reactiveState.state);
                    const newHistory = new Map(reactiveState.history);
                    const newCounts = new Map(reactiveState.updateCounts);

                    data.entries.forEach(entry => {
                        const id = entry.reactiveId;

                        // Update History
                        const historyList = [...(newHistory.get(id) || [])];
                        historyList.unshift({
                            ...entry,
                            timestamp: data.timestamp,
                            type: 'state_change'
                        } as unknown as ReactiveItem);
                        if (historyList.length > 50) historyList.pop();
                        newHistory.set(id, historyList);

                        // Update Counts
                        newCounts.set(id, (newCounts.get(id) || 0) + 1);

                        // Update State
                        const existing = newState.get(id) || {} as ReactiveItem;
                        newState.set(id, {
                            ...existing,
                            id,
                            name: entry.name,
                            oldValue: entry.oldValue,
                            newValue: entry.newValue,
                            valueType: entry.valueType,
                            timestamp: data.timestamp
                        });
                    });

                    reactiveState.state = newState;
                    reactiveState.history = newHistory;
                    reactiveState.updateCounts = newCounts;
                    break;
                }

                const id = data.reactiveId as string | undefined;
                if (id) {
                    // Track history - create new Map for reactivity
                    if (type === 'reactive_init' || type === 'state_change') {
                        const newHistory = new Map(reactiveState.history);
                        const historyList = [...(newHistory.get(id) || [])];
                        historyList.unshift(data as unknown as ReactiveItem);
                        if (historyList.length > 50) historyList.pop();
                        newHistory.set(id, historyList);
                        reactiveState.history = newHistory;

                        // Update count
                        const newCounts = new Map(reactiveState.updateCounts);
                        newCounts.set(id, (newCounts.get(id) || 0) + 1);
                        reactiveState.updateCounts = newCounts;
                    }

                    // Update state
                    const newState = new Map(reactiveState.state);
                    if (type === 'reactive_init' || type === 'state_change') {
                        const existing = newState.get(id) || {} as ReactiveItem;
                        newState.set(id, { ...existing, ...(data as unknown as ReactiveItem), id });
                    } else if (type === 'graph_change') {
                        const existing = newState.get(id);
                        if (existing) {
                            newState.set(id, {
                                ...existing,
                                dependencies: (data.dependencies as any[])?.map(d => d.id)
                            });
                        }
                    } else if (type === 'reactive_dispose') {
                        newState.delete(id);
                    }
                    reactiveState.state = newState;
                }
            }
            break;
    }
});
