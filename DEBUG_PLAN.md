# Chart Persistence Debugging Plan

## Problem Statement
The chart appearance changes between:
1. Original analysis (Test1): Shows complex multi-peaked distribution
2. Reloaded analysis (Test2): Shows different distribution shape

## Debugging Steps

### STEP 1: Verify Data at Creation Time
Add logging to track exactly what data is being created when particles are analyzed:

1. **In CoffeeAnalysisEngine.swift** - Log particle data:
   - Number of particles detected
   - Min/max particle sizes
   - Sample of first 10 particle sizes
   
2. **In CoffeeModels.swift** - Log computed distributions:
   - computeChartDataPoints() output
   - computeGranularDistribution() output
   - Number of data points in each
   - Sample data points with values

3. **In ResultsView.swift** - Log chart data preparation:
   - Which path is taken (particles/saved/fallback)
   - Input data (particles count or saved data count)
   - Output data points with values
   - Chart domain calculation

### STEP 2: Verify Data Storage
Track what's being saved:

1. **In CoffeeAnalysisHistory.swift - persistAnalyses()**:
   - Log the StorableAnalysis object being created
   - Verify chartDataPoints is not nil
   - Count and sample the chart data points
   - Verify successful encoding

2. **Check UserDefaults size**:
   - Log the size of encoded data
   - Verify it's being written

### STEP 3: Verify Data Loading
Track what's being loaded:

1. **In CoffeeAnalysisHistory.swift - loadSavedAnalyses()**:
   - Log when loading starts
   - Log decoded StorableAnalysis data
   - Verify chartDataPoints exists and has data
   - Log the CoffeeAnalysisResults being created

### STEP 4: Verify Chart Rendering
Track the final rendering:

1. **In ResultsView.swift - prepareChartData()**:
   - Log which branch is executed
   - Log the exact data being returned
   - Compare data point by point

### STEP 5: Add Debug View
Create a debug section in ResultsView to display:
- Data source (particles/saved/fallback)
- Number of data points
- Min/max values in data
- First 5 data points with exact values

## Implementation

Let's add comprehensive logging to trace the exact data flow: