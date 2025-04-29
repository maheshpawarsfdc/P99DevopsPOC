import { LightningElement, track, wire } from 'lwc';
import getAllCampaignsEmailMetrics from '@salesforce/apex/CampaignEmailMetricsController.getAllCampaignsEmailMetrics';
import getUserAndHisSubordinates from '@salesforce/apex/CampaignEmailMetricsController.getUserAndHisSubordinates';
import getCampaignTypes from '@salesforce/apex/CampaignEmailMetricsController.getCampaignTypes';
import USER_ID from '@salesforce/user/Id';

// Import Chart.js if you're planning to use it directly
// import { loadScript } from 'lightning/platformResourceLoader';
// import chartjs from '@salesforce/resourceUrl/chartjs';

export default class CampaignEmailDashboard extends LightningElement {
    @track campaignsData = [];
    @track error;
    @track isLoading = true;
    @track startDate;
    @track endDate;
    @track selectedUserId = USER_ID;
    @track userOptions = [];
    @track isDarkMode = false;
    @track sidebarCollapsed = false;
    
    
    // Advanced filter properties
    @track selectedCampaignType = 'All';
    @track campaignTypeOptions = [{ label: 'All Types', value: 'All' }];
    @track searchTerm = '';
    @track emailCompletionThreshold = 100; // Default to show all
    
    // Metrics for summary display
    @track totalLeads = 0;
    @track avgEmailCompletion = 0;
    @track isEmailCompletionUp = true;
    @track atRiskCampaigns = 0;
    
    // Performance scorecard metrics
    @track firstEmailScore = 0;
    @track followUpScore = 0;
    @track conversionScore = 0;
    @track overallScore = 0;

    // Chart objects (if using Chart.js)
    //charts = {};
    
    // Computed properties for UI classes
    get sidebarClass() {
        return this.sidebarCollapsed 
            ? 'sidebar collapsed' 
            : 'sidebar expanded';
    }
    
    get mainContentClass() {
        return this.sidebarCollapsed 
            ? 'main-content sidebar-collapsed' 
            : 'main-content sidebar-expanded';
    }
    
    get sidebarToggleIcon() {
        return this.sidebarCollapsed 
            ? 'utility:right' 
            : 'utility:left';
    }
    
    // Scorecard classes based on performance
    get firstEmailScoreClass() {
        return this.getScoreCardClass(this.firstEmailScore);
    }
    
    get followUpScoreClass() {
        return this.getScoreCardClass(this.followUpScore);
    }
    
    get conversionScoreClass() {
        return this.getScoreCardClass(this.conversionScore);
    }
    
    get overallScoreClass() {
        return this.getScoreCardClass(this.overallScore);
    }
    
    getScoreCardClass(score) {
        let baseClass = 'slds-box slds-box_small slds-text-align_center score-card ';
        if (score >= 80) return baseClass + 'score-excellent';
        if (score >= 60) return baseClass + 'score-good';
        if (score >= 40) return baseClass + 'score-average';
        return baseClass + 'score-poor';
    }

    connectedCallback() {
        // Initialize default date range (last 30 days)
        const today = new Date();
        this.endDate = this.formatDate(today);
        
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        this.startDate = this.formatDate(thirtyDaysAgo);
        
        // Load user data
        this.loadUserAndSubordinates();
        
        // Load campaign types
        this.loadCampaignTypes();
        
        // Load campaign data
        this.loadCampaignData();
        
        // Add custom styles
        //this.addCustomStyles();
        
        // Load Chart.js if planning to use it
        // this.loadChartJs();
    }
    
    // Method to load Chart.js library
    /*
    loadChartJs() {
        loadScript(this, chartjs)
            .then(() => {
                console.log('Chart.js loaded successfully');
                this.initializeCharts();
            })
            .catch(error => {
                console.error('Error loading Chart.js', error);
            });
    }
    
    initializeCharts() {
        // Will be implemented to create charts once data is loaded
        if (this.campaignsData.length > 0) {
            this.createPerformanceChart();
            this.createEmailCompletionChart();
            this.createCampaignTypeChart();
            this.createConversionRateChart();
        }
    }
    */

    formatDate(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }
    
    // Event Handlers
    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }
    
    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }

    handleUserChange(event) {
        this.selectedUserId = event.target.value;
    }
    
    handleCampaignTypeChange(event) {
        this.selectedCampaignType = event.target.value;
    }
    
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }
    
    handleThresholdChange(event) {
        this.emailCompletionThreshold = event.detail.value;
    }
    
    handleThemeToggle(event) {
        this.isDarkMode = event.target.checked;
        if (this.isDarkMode) {
            document.body.classList.add('dark-mode');
        } else {
            document.body.classList.remove('dark-mode');
        }
    }
    
    toggleSidebar() {
        this.sidebarCollapsed = !this.sidebarCollapsed;
    }
    
    handleRefresh() {
        this.loadCampaignData();
    }
    
    handleResetFilters() {
        // Reset filters to default values
        const today = new Date();
        this.endDate = this.formatDate(today);
        
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        this.startDate = this.formatDate(thirtyDaysAgo);
        
        this.selectedUserId = USER_ID;
        this.selectedCampaignType = 'All';
        this.searchTerm = '';
        this.emailCompletionThreshold = 100;
        
        // Refresh data
        this.loadCampaignData();
    }
    
    clearError() {
        this.error = undefined;
    }

    // Data loading methods
    loadUserAndSubordinates() {
        getUserAndHisSubordinates({ userid: USER_ID })
            .then(result => {
                console.log('User subordinates loaded:', result);
                let options = [{ label: 'Myself', value: USER_ID }];
                
                if (result && result.length > 0) {
                    result.forEach(user => {
                        options.push({ label: user.Name, value: user.Id });
                    });
                }
                
                this.userOptions = options;
                console.log('User options:', this.userOptions);
            })
            .catch(error => {
                console.error('Error fetching users', error);
                this.error = 'Failed to load user data: ' + this.reduceErrors(error);
            });
    }
    
    loadCampaignTypes() {
        getCampaignTypes()
            .then(result => {
                console.log('Campaign types loaded:', result);
                let options = [{ label: 'All Types', value: 'All' }];
                
                if (result && result.length > 0) {
                    result.forEach(type => {
                        options.push({ label: type, value: type });
                    });
                }
                
                this.campaignTypeOptions = options;
            })
            .catch(error => {
                console.error('Error fetching campaign types', error);
                this.error = 'Failed to load campaign types: ' + this.reduceErrors(error);
            });
    }

    loadCampaignData() {
        this.isLoading = true;
        this.error = undefined;
        
        console.log('Loading campaign data with filters:');
        console.log('Start Date:', this.startDate);
        console.log('End Date:', this.endDate);
        console.log('User ID:', this.selectedUserId);
        console.log('Campaign Type:', this.selectedCampaignType);
        console.log('Search Term:', this.searchTerm);
        console.log('Threshold:', this.emailCompletionThreshold);
        
        getAllCampaignsEmailMetrics({
            startDate: this.startDate,
            endDate: this.endDate,
            userId: this.selectedUserId,
            campaignType: this.selectedCampaignType === 'All' ? null : this.selectedCampaignType,
            searchTerm: this.searchTerm || null
        })
        .then(result => {
            console.log('Campaign data received:', result);
            if (result && result.length > 0) {
                // Process and filter the data
                let processedData = this.processData(result);
                
                // Apply threshold filter client-side
                if (this.emailCompletionThreshold < 100) {
                    processedData = processedData.filter(campaign => 
                        campaign.firstEmailPercentage <= this.emailCompletionThreshold
                    );
                }
                
                this.campaignsData = processedData;
                this.error = undefined;
                
                // Calculate summary metrics
                this.calculateSummaryMetrics();
                
                // Initialize charts if using Chart.js
                // this.initializeCharts();
            } else {
                this.campaignsData = [];
                this.error = 'No campaign data found for the selected criteria.';
            }
        })
        .catch(error => {
            console.error('Error loading campaign data:', error);
            this.error = 'Error loading campaign data: ' + this.reduceErrors(error);
            this.campaignsData = [];
        })
        .finally(() => {
            this.isLoading = false;
        });
    }
    
    // Process data to add additional metrics or formatting
    processData(results) {
        return results.map(campaign => {
            // Generate a unique id for key
            campaign.campaignId = campaign.campaignId || this.generateUniqueId();
            
            // Add card styling based on risk assessment
            campaign.isAtRisk = campaign.firstEmailPercentage < 50 || campaign.firstToFollowUpRate < 30;
            campaign.cardClass = 'slds-box campaign-card ' + (campaign.isAtRisk ? 'at-risk-card' : '');
            
            // Add trend indicators (mock data - would be real in a full implementation)
            campaign.firstEmailTrend = true;
            campaign.firstEmailTrendIcon = Math.random() > 0.5 ? 'utility:arrowup' : 'utility:arrowdown';
            campaign.firstEmailTrendClass = campaign.firstEmailTrendIcon === 'utility:arrowup' ? 'trend-icon-up' : 'trend-icon-down';
            
            campaign.firstFollowUpTrend = true;
            campaign.firstFollowUpTrendIcon = Math.random() > 0.5 ? 'utility:arrowup' : 'utility:arrowdown';
            campaign.firstFollowUpTrendClass = campaign.firstFollowUpTrendIcon === 'utility:arrowup' ? 'trend-icon-up' : 'trend-icon-down';
            
            campaign.secondFollowUpTrend = true;
            campaign.secondFollowUpTrendIcon = Math.random() > 0.5 ? 'utility:arrowup' : 'utility:arrowdown';
            campaign.secondFollowUpTrendClass = campaign.secondFollowUpTrendIcon === 'utility:arrowup' ? 'trend-icon-up' : 'trend-icon-down';
            
            campaign.thirdFollowUpTrend = true;
            campaign.thirdFollowUpTrendIcon = Math.random() > 0.5 ? 'utility:arrowup' : 'utility:arrowdown';
            campaign.thirdFollowUpTrendClass = campaign.thirdFollowUpTrendIcon === 'utility:arrowup' ? 'trend-icon-up' : 'trend-icon-down';
            
            // Add mock growth data
            campaign.leadsGrowth = Math.floor(Math.random() * 15);
            
            // Calculate performance score (simple algorithm)
            campaign.performanceScore = Math.round(
                (campaign.firstEmailPercentage * 0.3) + 
                (campaign.firstFollowUpPercentage * 0.3) + 
                (campaign.firstToFollowUpRate * 0.2) + 
                (campaign.firstToSecondFollowUpRate * 0.2)
            );
            
            // Score class for table view
            campaign.scoreClass = campaign.performanceScore >= 80 ? 'slds-text-color_success' : 
                (campaign.performanceScore >= 60 ? 'slds-text-color_default' : 
                 (campaign.performanceScore >= 40 ? 'slds-text-color_weak' : 'slds-text-color_error'));
                
            return campaign;
        });
    }
    
    calculateSummaryMetrics() {
        // Calculate total leads
        this.totalLeads = this.campaignsData.reduce((sum, campaign) => sum + campaign.totalLeads, 0);
        
        // Calculate average email completion percentage
        this.avgEmailCompletion = Math.round(
            this.campaignsData.reduce((sum, campaign) => sum + campaign.firstEmailPercentage, 0) / 
            this.campaignsData.length
        );
        
        // Set mock trend indicator (would be real in a full implementation)
        this.isEmailCompletionUp = Math.random() > 0.5;
        
        // Count at-risk campaigns
        this.atRiskCampaigns = this.campaignsData.filter(campaign => campaign.isAtRisk).length;
        
        // Calculate performance scores
        this.firstEmailScore = Math.round(
            this.campaignsData.reduce((sum, campaign) => sum + campaign.firstEmailPercentage, 0) / 
            this.campaignsData.length
        );
        
        this.followUpScore = Math.round(
            this.campaignsData.reduce((sum, campaign) => sum + (
                (campaign.firstFollowUpPercentage + campaign.secondFollowUpPercentage + campaign.thirdFollowUpPercentage) / 3
            ), 0) / this.campaignsData.length
        );
        
        this.conversionScore = Math.round(
            this.campaignsData.reduce((sum, campaign) => sum + (
                (campaign.firstToFollowUpRate + campaign.firstToSecondFollowUpRate + campaign.secondToThirdFollowUpRate) / 3
            ), 0) / this.campaignsData.length
        );
        
        this.overallScore = Math.round(
            (this.firstEmailScore * 0.4) + 
            (this.followUpScore * 0.3) + 
            (this.conversionScore * 0.3)
        );
    }
    
    // Helper methods
    generateUniqueId() {
        return 'campaign-' + Math.random().toString(36).substr(2, 9);
    }
    
    reduceErrors(error) {
        if (typeof error === 'string') {
            return error;
        }
        
        // UI API DML, Apex and network errors
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        
        // UI API read errors
        else if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        
        // JS errors
        else if (typeof error.message === 'string') {
            return error.message;
        }
        
        // Unknown error shape
        return 'Unknown error';
    }
    
    /* Chart.js implementation methods (if using Chart.js)
    createPerformanceChart() {
        const ctx = this.template.querySelector('.chart-container:nth-child(1) .chart-placeholder');
        ctx.innerHTML = '';
        
        const chartData = {
            labels: this.campaignsData.map(c => c.campaignName),
            datasets: [{
                label: 'Performance Score',
                data: this.campaignsData.map(c => c.performanceScore),
                backgroundColor: 'rgba(75, 202, 129, 0.2)',
                borderColor: 'rgba(75, 202, 129, 1)',
                borderWidth: 1
            }]
        };
        
        this.charts.performance = new Chart(ctx, {
            type: 'bar',
            data: chartData,
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100
                    }
                }
            }
        });
    }
    
    createEmailCompletionChart() {
        // Implementation for email completion trend chart
    }
    
    createCampaignTypeChart() {
        // Implementation for campaign type comparison chart
    }
    
    createConversionRateChart() {
        // Implementation for follow-up conversion chart
    }
    */
}